import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).parents[1]


class MultiCdhitSchedulerContractTests(unittest.TestCase):
    def test_multicdhit_selects_scheduler_specific_child_options(self):
        source = (REPO_ROOT / "modules/local/geneset/multi_cdhit.nf").read_text()

        self.assertIn(
            "params.cdhit_queue_system ?: params.drep_queue_system ?: 'slurm'",
            source,
        )
        self.assertIn("case 'sge':", source)
        self.assertIn("cdhit_queue_type = 'SGE'", source)
        self.assertIn("-q ${cdhit_queue} -pe smp", source)
        self.assertIn("h_rss=${params.cdhit_split_mem}G", source)
        self.assertIn("--T ${cdhit_queue_type}", source)
        self.assertNotIn("--T slurm --Q", source)

    def test_multicdhit_scheduler_parameters_are_declared(self):
        config = (REPO_ROOT / "nextflow.config").read_text()
        schema = json.loads((REPO_ROOT / "nextflow_schema.json").read_text())
        geneset = schema["definitions"]["geneset_options"]["properties"]

        self.assertIn("cdhit_queue_system           = null", config)
        self.assertIn("cdhit_queue                  = null", config)
        self.assertIn("cdhit_split_mem              = 15", config)
        self.assertEqual(
            geneset["cdhit_queue_system"]["enum"],
            ["slurm", "pbs", "sge"],
        )
        self.assertEqual(geneset["cdhit_split_mem"]["default"], 15)

    def test_scheduler_submission_failure_is_fatal(self):
        source = (REPO_ROOT / "bin/cd-hit-cluster.pl").read_text()

        self.assertIn("system($submit_cmd) == 0", source)
        self.assertIn("Failed to submit $job with $queue_type", source)

    def test_sge_script_preserves_literal_directives_and_path_export(self):
        source = (REPO_ROOT / "bin/cd-hit-cluster.pl").read_text()

        self.assertIn("print QUEUE '#$ -S /bin/bash'", source)
        self.assertIn("print QUEUE '#$ -v PATH'", source)
        self.assertNotIn('"#!/bin/sh\\n#$ -S', source)


if __name__ == "__main__":
    unittest.main()
