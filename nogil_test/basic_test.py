import subprocess
import importlib
import build_extension

def run(env, python_path):
  source = subprocess.check_output([python_path + " -c 'import nogil_extension; a = nogil_extension.bag(); print(a)'"],
          env=env,
          shell=True,
          )
  failure_count = 0
  if source != b'4.0\n42.0\n':
    failure_count = 1
  
  result_dict = {'failed': failure_count, 'stdout': source}
  return result_dict
