# -*- coding: utf-8 -*-

import sys
import urllib.parse

sys.stdout.write(urllib.parse.unquote(input(), encoding='utf-8'))
