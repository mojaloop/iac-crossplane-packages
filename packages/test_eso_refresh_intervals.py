#!/usr/bin/env python3
"""Policy tests for ESO refresh interval defaults and propagation."""

import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).parent

DEFINITIONS = [
    "objectstores/compositions/object-store/resources/definition.yaml",
    "objectstores/compositions/ceph-bucket/resources/definition.yaml",
    "objectstores/compositions/s3-bucket/resources/definition.yaml",
    "env-onboard-config/compositions/env-aws-preconfig/resources/definition.yaml",
    "gitlab/compositions/post-config/resources/definition.yaml",
    "utils/compositions/bucket-secret/resources/definition.yaml",
    "utils/compositions/percona-role/resources/definition.yaml",
    "nb-config/compositions/nboperatorbootstrap/resources/definition.yaml",
    "nb-config/compositions/netbird-env-config/resources/definition.yaml",
]

KCL_PROPAGATION = {
    "objectstores/compositions/object-store/resources/kcl-step.k": (
        "esoRefreshInterval = parameters?.esoRefreshInterval",
        2,
    ),
    "objectstores/compositions/ceph-bucket/resources/kcl-step.k": (
        "refreshInterval = parameters?.secret?.esoRefreshInterval",
        1,
    ),
    "objectstores/compositions/s3-bucket/resources/kcl-step.k": (
        "refreshInterval = parameters?.secret?.esoRefreshInterval",
        1,
    ),
    "env-onboard-config/compositions/env-aws-preconfig/resources/kcl-step.k": (
        "refreshInterval = parameters.esoRefreshInterval",
        1,
    ),
    "gitlab/compositions/post-config/resources/kcl-step.k": (
        "refreshInterval = p?.esoRefreshInterval",
        1,
    ),
    "utils/compositions/bucket-secret/resources/kcl-step.k": (
        "refreshInterval = parameters?.esoRefreshInterval",
        1,
    ),
    "utils/compositions/percona-role/resources/kcl-step.k": (
        "refreshInterval = parameters?.esoRefreshInterval",
        1,
    ),
    "nb-config/compositions/nboperatorbootstrap/resources/kcl-step.k": (
        "refreshInterval = parameters.pushSecret.esoRefreshInterval",
        1,
    ),
    "nb-config/compositions/netbird-env-config/resources/kcl-step.k": (
        "refreshInterval = parameters.pushSecret.esoRefreshInterval",
        1,
    ),
}


def find_fields(value, field_name):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == field_name:
                yield child
            yield from find_fields(child, field_name)
    elif isinstance(value, list):
        for child in value:
            yield from find_fields(child, field_name)


class EsoRefreshIntervalTest(unittest.TestCase):
    def test_all_affected_schema_defaults_are_15m(self):
        for relative_path in DEFINITIONS:
            with self.subTest(definition=relative_path):
                definition = yaml.safe_load((ROOT / relative_path).read_text())
                fields = list(find_fields(definition, "esoRefreshInterval"))
                self.assertEqual(1, len(fields))
                self.assertEqual("15m", fields[0].get("default"))

    def test_all_affected_resources_use_configured_interval(self):
        for relative_path, (assignment, count) in KCL_PROPAGATION.items():
            with self.subTest(composition=relative_path):
                source = (ROOT / relative_path).read_text()
                self.assertEqual(count, source.count(assignment))
                self.assertNotIn('refreshInterval = "1m"', source)


if __name__ == "__main__":
    unittest.main()
