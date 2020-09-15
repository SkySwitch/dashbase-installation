#!/usr/bin/env python

import argparse
import os
import time
import fnmatch


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action='store_true')
    parser.add_argument("-p", "--pattern", help="filename pattern", default="*")
    parser.add_argument("-d", "--dirname", help="The dirname to store files", required=True)
    parser.add_argument("-r", "--retention", help="if file modify more than retention (second), will remove",
                        type=int, required=True)
    args = parser.parse_args()
    dirname = args.dirname
    verbose = args.verbose
    retention = args.retention
    now = time.time()

    if not os.path.isdir(dirname):
        print("ERROR: {} is a dir or not existing".format(dirname))
        return

    if verbose:
        print("Now: {}".format(now))
        print("Directory: {}".format(dirname))
        print("Retention: {}".format(retention))

    for dirpath, _, filenames in os.walk(os.path.abspath(dirname)):
        for f in filenames:
            if not fnmatch.fnmatch(f, args.pattern):
                continue

            filepath = os.path.join(dirpath, f)
            file_mtime = os.stat(filepath).st_mtime

            if file_mtime < now - retention:
                os.remove(filepath)
                op = "Removed"
            else:
                op = "Skipped"

            if verbose:
                print("VERBOSE: {} file: {}, mtime: {}".format(op, filepath, file_mtime))

    else:
        print("Finished removing old files")


if __name__ == "__main__":
    main()
