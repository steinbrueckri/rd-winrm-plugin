#!/usr/bin/ruby
require 'winrm'
user = ENV['RD_CONFIG_USER']
pass = ENV['RD_CONFIG_PASS'].dup # for some reason this string is frozen, so we duplicate it
host = ENV['RD_NODE_HOSTNAME']
realm = ENV['RD_CONFIG_KRB5_REALM']
command = ENV['RD_EXEC_COMMAND']
endpoint = "http://#{host}:5985/wsman"
output = ''

# Wrapper ro avoid strange and undocumented behavior of rundeck
# Should be deleted after rundeck fix
newcommand = command.gsub(/'"'"'/, '')

# Wrapper for avoid unix style file copying in command run
# not accept chmod call
# replace rm -f into rm -force
# auto copying renames file from .sh into .ps1
# so in that case we should call file with ps1 extension
exit 0 if newcommand.include? 'chmod +x /tmp/'
newcommand = newcommand.gsub(/rm -f \/tmp\//, 'rm -force /tmp/') if newcommand.include? 'rm -f /tmp/'
newcommand = newcommand.gsub(/\.sh/, '.ps1') if /\/tmp\/.*\.sh/.match(newcommand)

# TODO: ENV['WINRM_LOG'] = '' or 'debug, info, warn, or error'

#if loglevel == 'debug'
  puts 'variables is:'
  puts "realm is #{realm}"
  puts "endpoint is #{endpoint}"
  puts "user is #{user}"
  puts "pass is #{pass}"
  puts "command is #{command}"
  puts "newcommand is #{newcommand}"

  puts "ENV"
  ENV.each do |k,v|
    puts "'key' => #{k}, 'value' => #{v}"
  end
#end

def stderr_text (stderr)
  doc = REXML::Document.new(stderr)
  text = doc.root.get_elements('//S').map(&:text).join
  text.gsub(/_x(\h\h\h\h)_/) do
    code = Regexp.last_match[1]
    code.hex.chr
  end
end

winrm = WinRM::WinRMWebService.new(endpoint, :plaintext, user: user, pass: pass, :disable_sspi => true)
winrm.set_timeout(60000)

result = winrm.powershell(newcommand)
result[:data].each do |output_line|
    output = "#{output}#{output_line[:stderr]}" if output_line.has_key?(:stderr)
      STDOUT.print output_line[:stdout] if output_line.has_key?(:stdout)
end
STDERR.print stderr_text(output) if output != ''
exit result[:exitcode] if result[:exitcode] != 0


#winrm.powershell(newcommand) do |stdout, stderr|
#  STDOUT.print stdout
#  STDERR.print stderr
#end
