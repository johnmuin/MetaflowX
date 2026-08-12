import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).parents[1]


class DrepProcessSchedulerContractTests(unittest.TestCase):
    def test_split_scheduler_is_independent_from_wrapper_executor(self):
        source = (REPO_ROOT / "modules/local/binning/drep.nf").read_text()

        self.assertIn(
            "params.drep_queue_system ?: task.executor",
            source,
        )
        self.assertIn("-T ${drep_queue_system}", source)
        self.assertIn("-q ${drep_queue}", source)
        self.assertIn(
            'if [ "${task.executor}" != "local" ]',
            source,
        )

    def test_queue_system_parameter_is_declared(self):
        config = (REPO_ROOT / "nextflow.config").read_text()
        schema = json.loads((REPO_ROOT / "nextflow_schema.json").read_text())
        binning = schema["definitions"]["binning_options"]["properties"]

        self.assertIn("drep_queue_system           = null", config)
        self.assertIn("drep_queue                  = null", config)
        self.assertEqual(
            binning["drep_queue_system"]["enum"],
            ["slurm", "pbs", "sge"],
        )
        self.assertEqual(binning["drep_queue"]["type"], "string")


if __name__ == "__main__":
    unittest.main()
