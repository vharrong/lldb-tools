#!/usr/bin/env python
"""Command to generate a test code coverage report from an lldb build.

The lldb build must have been generated with the equivalent of
'lldb_configure.py [-c] --coverage'.

See lldb_run_code_coverage.py --help for command line options.
"""


import argparse
import os
import os.path
import subprocess
import sys
import tempfile
import workingdir


g_script_dir = os.path.dirname(os.path.realpath(__file__))
g_lcov_exe = os.path.realpath(
    os.path.join(g_script_dir, '..', 'lcov', 'bin', 'lcov'))
g_genhtml_exe = os.path.realpath(
    os.path.join(g_script_dir, '..', 'lcov', 'bin', 'genhtml'))


def _AssertCommandWorks(command_sequence, resolution_hint):
  try:
    with open(os.devnull, 'w') as fnull:
      subprocess.check_call(
          command_sequence,
          stdout=fnull,
          stderr=fnull)
  except subprocess.CalledProcessError as e:
    print >>sys.stderr, (
        '"{}" execution failed, return code: {} (hint: {})'.format(
            ' '.join(command_sequence),
            e.returncode,
            resolution_hint))
    exit(1)
  except OSError as e:
    print >>sys.stderr, (
        '"{}" execution failed, os error: {} (hint: {})'.format(
            ' '.join(command_sequence),
            e,
            resolution_hint))
    exit(1)


def _RunCommand(command_sequence, args):
  if args.verbose:
    print 'executing command: ' + ' '.join(command_sequence)
  try:
    subprocess.check_call(command_sequence)
  except subprocess.CalledProcessError as e:
    print >>sys.stderr, (
        '"{}" execution failed, return code: {}'.format(
            ' '.join(command_sequence),
            e.returncode))
    exit(1)
  except OSError as e:
    print >>sys.stderr, (
        '"{}" execution failed, os error: {}'.format(
            ' '.join(command_sequence),
            e))
    exit(1)


def _ParseCommandLine():
  """Perform command line parsing via argparse.

  Returns:
    Parsed arguments per argparse.parse_args().
  """
  parser = argparse.ArgumentParser(
      description='Run code coverage against lldb tests')

  parser.add_argument(
      '--build-dir', '-b', action='store',
      help='Specify the build directory that will be code covered.')

  parser.add_argument(
      '--cmake', '-c', action='store_true', dest='use_cmake',
      help=('Run tests assuming cmake/ninja '
            '(default: run tests assuming configure/gmake).'))

  parser.add_argument(
      '--output-dir', '-o', action='store', default='coverage-report',
      help=('Output directory for code coverage report '
            '(default: ./coverage-report).'))

  parser.add_argument(
      '-v', action='store_true', dest='verbose', help='Use verbose output.')

  return parser.parse_args()


def _CheckPrerequisites():
  _AssertCommandWorks([g_lcov_exe, '-v'],
                      'install lcov')
  _AssertCommandWorks(['gcov', '-v'],
                      'install a compiler with gcov support')
  _AssertCommandWorks(['genhtml', '-v'],
                      'install lcov (e.g. sudo apt-get install lcov)')


def _CreateTempFilename(args):
  # create a temp directory
  temp_dir = tempfile.mkdtemp()
  args.temp_file = os.path.join(temp_dir, 'code_coverage.info')
  if args.verbose:
    print 'writing code coverage info to: ' + args.temp_file


def _InitializeCapture(args):
  """Perform commands needed to initialize code coverage capture.

  Args:
    args: argparse-style args as parsed via the command line.
  """
  zero_counters_command = [
      g_lcov_exe,
      '--zerocounters',
      '--directory',
      os.path.join(args.build_dir, 'tools', 'lldb', 'source')]
  _RunCommand(zero_counters_command, args)

  initialize_capture_command = [
      g_lcov_exe,
      '--capture',
      '--initial',
      '--directory',
      os.path.join(args.build_dir, 'tools', 'lldb', 'source'),
      '--output-file',
      args.temp_file
      ]
  _RunCommand(initialize_capture_command, args)


def _RunTests(args):
  with workingdir.WorkingDir(args.build_dir):
    if args.use_cmake:
      _RunCommand(['ninja', 'check-lldb'], args)
    else:
      _RunCommand(['make', '-C', os.path.join('tools', 'lldb', 'test')], args)


def _PostCapture(args):
  """Perform commands needed to finish up code coverage capture.

  This step finishes up book-keeping needed prior to generating
  a code coverage report.

  Args:
    args: argparse-style args as parsed via the command line.
  """
  post_capture_command = [
      g_lcov_exe,
      '--no-checksum',
      '--directory',
      os.path.join(args.build_dir, 'tools', 'lldb', 'source'),
      '--capture',
      '--output-file',
      args.temp_file
      ]
  _RunCommand(post_capture_command, args)


def _GenerateHtml(args):
  os.makedirs(args.output_dir)

  generate_html_command = [
      g_genhtml_exe,
      '-o',
      args.output_dir,
      args.temp_file]
  _RunCommand(generate_html_command, args)


def main():
  _CheckPrerequisites()
  args = _ParseCommandLine()

  _CreateTempFilename(args)
  _InitializeCapture(args)
  _RunTests(args)
  _PostCapture(args)
  _GenerateHtml(args)


if __name__ == '__main__':
  main()
