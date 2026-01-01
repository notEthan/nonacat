$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require('nonacat')

# NO EXPECTATIONS
ENV["MT_NO_EXPECTATIONS"] = ''

require('minitest/autorun')

Minitest::Test.make_my_diffs_pretty!
