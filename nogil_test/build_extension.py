import subprocess
import importlib
import sys

def build_ext(env):
  # Build the cython_lwan_coro when installing it in slapos
  # subprocess.check_output(['python3', 'setup.py', 'build_ext', '--inplace'], cwd='./cython_lwan_coro/', env=env)
  source = ''
  failure_count = 0
  try:
    sys.path.append('./cython_lwan_coro/')
    wrapper = importlib.import_module('wrapper')
  except ImportError as e:
    failure_count = 1
    source = str(e)
    print(source) # Will be captured by check_output
