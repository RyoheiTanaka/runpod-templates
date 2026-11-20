import signal
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import start


class StartTests(unittest.TestCase):
    def test_custom_model_revision_and_quantization_are_separate_arguments(self):
        command = start.build_command({
            "MODEL_ID": "org/custom-model", "MODEL_REVISION": "fixed-revision",
            "MAX_MODEL_LEN": "8192", "ENABLE_AUTO_TOOL_CHOICE": "false",
            "ENFORCE_EAGER": "false",
            "VLLM_EXTRA_ARGS_JSON": '["--quantization", "awq"]',
        })
        self.assertEqual(command[:3], ["vllm", "serve", "org/custom-model"])
        self.assertIn("fixed-revision", command)
        self.assertIn("8192", command)
        self.assertNotIn("--tool-call-parser", command)
        self.assertNotIn("--enforce-eager", command)
        self.assertEqual(command[-2:], ["--quantization", "awq"])

    def test_invalid_configuration_fails_without_starting_a_server(self):
        for env in ({"MODEL_ID": "--help"}, {"MAX_MODEL_LEN": "0"},
                    {"GPU_MEMORY_UTILIZATION": "nan"}, {"GPU_MEMORY_UTILIZATION": "1.1"},
                    {"ENABLE_AUTO_TOOL_CHOICE": "yes"}, {"TOOL_CALL_PARSER": ""},
                    {"VLLM_EXTRA_ARGS_JSON": '{}'}, {"VLLM_EXTRA_ARGS_JSON": '[1]'},
                    {"VLLM_EXTRA_ARGS_JSON": 'not-json'}):
            with self.subTest(env=env), self.assertRaises(ValueError):
                start.build_command(env)

    def test_extra_flags_cannot_override_network_or_auth(self):
        for flag in ("--host=0.0.0.0", "--api-key=unsafe", "--port=80", "--config=other.yaml"):
            with self.subTest(flag=flag), self.assertRaises(ValueError):
                start.build_command({"VLLM_EXTRA_ARGS_JSON": start.json.dumps([flag])})

    def test_api_key_is_required_and_never_added_to_command(self):
        for value in ("", "your-vllm-api-key", "change-me"):
            with self.assertRaises(ValueError):
                start.prepare_environment({"VLLM_API_KEY": value})
        with tempfile.TemporaryDirectory() as directory:
            env = start.prepare_environment({"VLLM_API_KEY": "test-only-value", "WORKSPACE": directory,
                                             "HF_TOKEN": "your-huggingface-token"})
            self.assertTrue(Path(env["HF_HOME"]).is_dir())
            self.assertNotIn("HF_TOKEN", env)
            self.assertNotIn("test-only-value", start.build_command(env))

    @patch("start.subprocess.run")
    def test_ssh_key_sync_is_idempotent_and_explicit_override_wins(self, run):
        run.return_value = Mock(returncode=0)
        with tempfile.TemporaryDirectory() as directory:
            ssh_dir = Path(directory) / "ssh"
            env = {"PUBLIC_KEY": "old-key", "SSH_PUBLIC_KEY": "new-key"}
            start.prepare_ssh(env, ssh_dir)
            start.prepare_ssh(env, ssh_dir)
            self.assertEqual((ssh_dir / "authorized_keys").read_text(), "new-key\n")

    @patch("start.subprocess.run")
    def test_invalid_ssh_key_does_not_replace_existing_keys(self, run):
        run.return_value = Mock(returncode=1)
        with tempfile.TemporaryDirectory() as directory:
            ssh_dir = Path(directory)
            (ssh_dir / "authorized_keys").write_text("keep-me\n")
            with self.assertRaises(ValueError):
                start.prepare_ssh({"PUBLIC_KEY": "invalid-key"}, ssh_dir)
            self.assertEqual((ssh_dir / "authorized_keys").read_text(), "keep-me\n")

    @patch("start.stop_process")
    @patch("start.time.sleep")
    @patch("start.subprocess.Popen")
    def test_vllm_exit_stops_both_services(self, popen, sleep, stop):
        ssh, model = Mock(pid=101), Mock(pid=102)
        ssh.poll.return_value = None
        model.poll.return_value = 7
        popen.side_effect = [ssh, model]
        self.assertEqual(start.supervise(["vllm"], {}), 7)
        self.assertEqual([call.args[0] for call in stop.call_args_list], [model, ssh])

    @patch("start.stop_process")
    @patch("start.time.sleep")
    @patch("start.subprocess.Popen")
    def test_ssh_start_failure_does_not_start_model(self, popen, sleep, stop):
        ssh = Mock(pid=101)
        ssh.poll.return_value = 1
        popen.return_value = ssh
        with self.assertRaisesRegex(RuntimeError, "sshd failed"):
            start.supervise(["vllm"], {})
        self.assertEqual(popen.call_count, 1)
        stop.assert_called_once_with(ssh)

    @patch("start.os.killpg", side_effect=ProcessLookupError, create=True)
    def test_cleanup_handles_already_exited_group(self, killpg):
        start.stop_process(Mock(pid=42))
        killpg.assert_called_once_with(42, signal.SIGTERM)

    @patch("start.stop_process")
    @patch("start.time.sleep")
    @patch("start.subprocess.Popen")
    def test_model_launch_failure_still_stops_ssh(self, popen, sleep, stop):
        ssh = Mock(pid=101)
        ssh.poll.return_value = None
        popen.side_effect = [ssh, OSError("launch failed")]
        with self.assertRaises(OSError):
            start.supervise(["vllm"], {})
        stop.assert_called_once_with(ssh)

    @patch("start.stop_process")
    @patch("start.time.sleep")
    @patch("start.subprocess.Popen")
    def test_stop_signal_terminates_both_services_and_restores_handler(self, popen, sleep, stop):
        ssh, model = Mock(pid=101), Mock(pid=102)
        ssh.poll.return_value = model.poll.return_value = None
        popen.side_effect = [ssh, model]
        original = signal.getsignal(signal.SIGTERM)
        calls = 0

        def send_stop(_):
            nonlocal calls
            calls += 1
            if calls == 2:
                signal.getsignal(signal.SIGTERM)(signal.SIGTERM, None)

        sleep.side_effect = send_stop
        self.assertEqual(start.supervise(["vllm"], {}), 0)
        self.assertEqual(stop.call_count, 2)
        self.assertEqual(signal.getsignal(signal.SIGTERM), original)


if __name__ == "__main__":
    unittest.main()
