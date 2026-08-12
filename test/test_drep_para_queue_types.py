import argparse
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "bin" / "dRep_para.py"
SPEC = importlib.util.spec_from_file_location("drep_para", MODULE_PATH)
DREP_PARA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DREP_PARA)


class QueueSystemTypeTests(unittest.TestCase):
    def test_normalizes_nextflow_executor_names(self):
        expected = {
            "slurm": "slurm",
            "SLURM": "slurm",
            "pbs": "pbs",
            "PBS": "pbs",
            "pbspro": "pbs",
            "SGE": "sge",
            "sge": "sge",
        }

        for value, normalized in expected.items():
            with self.subTest(value=value):
                self.assertEqual(
                    DREP_PARA.normalize_queue_system_type(value), normalized
                )

    def test_rejects_unsupported_executor(self):
        with self.assertRaises(argparse.ArgumentTypeError):
            DREP_PARA.normalize_queue_system_type("local")

    def test_parses_scheduler_job_ids(self):
        outputs = {
            "Submitted batch job 207103": 207103,
            "207104.server": 207104,
            'Your job 207105 ("job") has been submitted': 207105,
        }

        for output, job_id in outputs.items():
            with self.subTest(output=output):
                self.assertEqual(DREP_PARA.parse_job_id(output), job_id)

    def test_generates_scheduler_specific_headers(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            drep = object.__new__(DREP_PARA.DrepParallel)
            drep.shelldir = Path(tmpdir)
            drep.projectname = "project"
            drep.queue = "queue"
            drep.threads = 4
            drep.max_mem = 16

            drep.queue_system_type = "pbs"
            self.assertIn("#PBS -N job", drep._get_command_header("job"))

            drep.queue_system_type = "sge"
            sge_header = drep._get_command_header("job")
            self.assertIn("#$ -N job", sge_header)
            self.assertIn("#$ -l h_rss=16G,mem_free=16G", sge_header)

    def test_submits_sge_with_qsub_and_parses_standard_output(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            bash_file = Path(tmpdir) / "job.sh"
            bash_file.touch()
            task = DREP_PARA.Task("job", bash_file)
            result = subprocess.CompletedProcess(
                args=[],
                returncode=0,
                stdout='Your job 207104 ("job") has been submitted\n',
                stderr="",
            )

            with mock.patch.object(DREP_PARA.subprocess, "run", return_value=result) as run:
                task.submit("sge")

            run.assert_called_once_with(
                ["qsub", str(bash_file)], capture_output=True, text=True
            )
            self.assertEqual(task.job_id, 207104)
            self.assertEqual(task.status, "Submit")

    def test_generated_job_script_exposes_drep_environment_dependencies(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            drep = object.__new__(DREP_PARA.DrepParallel)
            drep.drep_exe = Path("/opt/conda env/bin/dRep")
            bash_file = Path(tmpdir) / "job.sh"

            drep._write_bash_file(
                bash_file,
                "#!/bin/bash\n#$ -N job\n",
                f"{drep.drep_exe} dereplicate output",
            )

            script = bash_file.read_text()
            export = "export PATH='/opt/conda env/bin':\"${PATH:-}\""
            self.assertIn(export, script)
            self.assertLess(script.index(export), script.index("dRep dereplicate"))


if __name__ == "__main__":
    unittest.main()
