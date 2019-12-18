#!/usr/bin/env python

import os
from pathlib import Path
import sys
import yaml

LICENSE_FILE = "license.yml"

license_dir = Path(os.environ['DASHBASE_HOME'])

license_file = license_dir / LICENSE_FILE

if not license_file.exists():
    sys.exit("License file not found!")

license = yaml.load(open(license_file.absolute().as_posix(), 'r'))
print ('License file found')
print ("user: {}".format(license["username"]))
print ("license: {}".format(license["license"]))

# TODO call license endpoint to validate license
# print out if license if valid
# print out the number of days left on the license
