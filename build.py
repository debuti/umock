#!/usr/bin/env python3
import os
import argparse
from pathlib import Path
import shutil

SCRIPT_PATH = Path(os.path.realpath(__file__)).parent
BUILD_PATH = SCRIPT_PATH / "build"


def runcmd(cmd, cwd=None):
    if cwd:
        owd = os.getcwd()
        os.chdir(cwd)
    if 0 != os.system(cmd):
        raise Exception("Command failed")
    if cwd:
        os.chdir(owd)


def main(args):
    if not BUILD_PATH.exists():
        args.clean = True
    if args.clean:
        shutil.rmtree(BUILD_PATH, ignore_errors=True)
        BUILD_PATH.mkdir()
        try:
            runcmd(
                f"cmake .. {'-DTESTING=ON' if args.test else ''}", cwd=BUILD_PATH)
        except Exception as error:
            raise Exception("Configure failed") from error

    try:
        runcmd(f"cmake --build .", cwd=BUILD_PATH)
    except Exception as error:
        raise Exception("Build failed") from error

    try:
        runcmd(f"valgrind --leak-check=full ./mylib_test --output-on-failure" if args.test else f"./mylib_app", cwd=BUILD_PATH)
    except Exception as error:
        raise Exception("Test failed") from error


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--clean', action='store_true',
                        help='Clean the project')
    parser.add_argument('-t', '--test', action='store_true',
                        help='Run the testers')
    main(parser.parse_args())
