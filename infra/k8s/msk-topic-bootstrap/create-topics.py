#!/usr/bin/env python3
"""Create MSK topics from /config/topics.json using IAM auth."""
import json
import os
import subprocess
import sys

BOOTSTRAP = os.environ["BOOTSTRAP_SERVERS"]
CONFIG = "/config/topics.json"
PROPS = "/config/client.properties"
KAFKA = os.environ.get("KAFKA_BIN", "/usr/bin/kafka-topics")
CLASSPATH = "/plugins/aws-msk-iam-auth.jar"
ENV = {**os.environ, "CLASSPATH": CLASSPATH}


def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(args, env=ENV, capture_output=True, text=True)


def list_topics() -> set[str]:
    result = run([KAFKA, "--bootstrap-server", BOOTSTRAP, "--command-config", PROPS, "--list"])
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)
    return {line.strip() for line in result.stdout.splitlines() if line.strip()}


def create_topic(name: str, partitions: int, replication: int) -> None:
    existing = list_topics()
    if name in existing:
        print(f"exists: {name}")
        return

    print(f"creating: {name} partitions={partitions} rf={replication}")
    result = run(
        [
            KAFKA,
            "--bootstrap-server",
            BOOTSTRAP,
            "--command-config",
            PROPS,
            "--create",
            "--topic",
            name,
            "--partitions",
            str(partitions),
            "--replication-factor",
            str(replication),
            "--config",
            "min.insync.replicas=2",
        ]
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        sys.exit(result.returncode)


def main() -> None:
    with open(CONFIG, encoding="utf-8") as fh:
        topics = json.load(fh)
    for name in sorted(topics):
        cfg = topics[name]
        create_topic(name, cfg["partitions"], cfg["replication_factor"])
    print("topic bootstrap complete")


if __name__ == "__main__":
    main()
