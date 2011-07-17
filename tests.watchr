# Run me with:
#   $ watchr tests.watchr

# --------------------------------------------------
# Rules
# --------------------------------------------------

# if we edit main lib files
watch( '^lib/(.*).rb'                               )  { ruby all_tests }
# if we edit Gemfile or Gemspec.
watch( '^(Gemfile*|resque-retry.gemspec)'     )  { ruby all_tests }
# if we edit any test related files.
watch( '^test/.*'                  )  { ruby all_tests }

#### INTERGRATION

# --------------------------------------------------
# Signal Handling
# --------------------------------------------------
Signal.trap('QUIT') { ruby all_tests  } # Ctrl-\
Signal.trap('INT' ) { abort("\n") } # Ctrl-C

# --------------------------------------------------
# Helpers
# --------------------------------------------------
def ruby(*paths)
  run "bundle exec ruby #{gem_opt} -I.:lib:test -e'%w( #{paths.flatten.join(' ')} ).each { |p| require p }'"
end

def all_tests
  Dir['test/*_test.rb']
end

def run(cmd)
  puts   cmd
  system cmd
end

def gem_opt
  defined?(Gem) ? '-rubygems' : ''
end