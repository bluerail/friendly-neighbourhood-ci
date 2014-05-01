#!/usr/bin/env ruby
#
# Your friendly neighbourhood continues integration annoyer
# https://github.com/bluerail/friendly-neighbourhood-ci
# 
# Copyright © 2014 Martin Tournoij <martin@lico.nl>
# See the end of the file for full copyright
#


require 'net/smtp'
require 'optparse'
require 'yaml'


class Tester
  def initialize repo, options={}
    @repo = repo
    @branch = nil

    defaults = {
      verbose: false,
      dryrun: false,
      runalways: false,
      mailto: '%a,%c',
      from: 'ci@example.com',
      testcmd: 'bundle exec rake'
    }

    if File.exists? "#{@repo}/.ci-settings.yaml"
      YAML.load_file("#{@repo}/.ci-settings.yaml").each do |k, v|
        defaults[k.to_sym] = v
      end
    end

    @options = defaults.merge options
    verbose @options
  end


  def start
    get_branches.each do |branch|
      Dir.mkdir "#{@repo}/.git/ci" unless Dir.exists? "#{@repo}/.git/ci"
      checkout_branch branch
      if !@options[:runalways] && !branch_has_changed?
        verbose "Branch hasn't changed, doing nothing"
        next
      end

      success, output = run_tests
      mail output unless success

      fp = File.open cookie, 'w'
      fp.write last_commit[:date]
      fp.close()
    end
  end


  def run cmd, exit_on_error=true
    verbose "Running #{cmd}"
    out = `#{cmd}`

    if $?.exitstatus != 0 && !exit_on_error
      puts "Error running #{cmd}:\n#{out}"
      exit(1)
    end

    return out
  end


  def get_branches
    run("git -C '#{@repo}' branch -a 2>&1 | sed -r 's|^[\* ]+(remotes/origin/)?||; /^HEAD/d' | sort -u").split "\n"
  end


  def checkout_branch branch
    verbose "Checkout out #{branch}"
    @branch = branch
    run "git -C '#{@repo}' checkout '#{@branch}' 2>&1"
  end


  def pull
    run "git -C '#{@repo}' pull --force"
  end


  def last_commit
    out = run("git -C '#{@repo}' log -1 --format='%H||%aE||%cE||%s||%aD' 2>&1").split('||').map(&:strip)

    return {
      hash: out.shift,
      author: out.shift,
      committer: out.shift,
      subject: out.shift,
      date: out.shift,
    }
  end


  def branch_has_changed?
    return true unless File.exists? cookie
    return File.open(cookie, 'r').read() != last_commit[:date]
  end


  def run_tests
    verbose "Running tests for #{@repo} #{@branch}"

    if @options[:dryrun]
      out = '-n given'
      status = [0]
    else
      status = []
      @options[:testcmd].split("\n").each do |cmd|
        out = `cd #{@repo} && #{cmd} 2>&1`
        status << $?.exitstatus
      end
    end

    verbose "Success: #{status}"
    return [status.sort[-1] == 0, out]
  end


  def mail output
    last = last_commit
    msg = []
    msg << "Subject: CI failed for #{@repo}:#{@branch}"
    msg << ""
    msg << "Listen very carefully, I shall say this only once!"
    msg << ""
    msg << "It would seem that tests are failing for the #{@branch} branch in #{@repo}. Yikes!"
    msg << ""
    msg << "The last commit was:"
    msg << ""
    msg << "    #{last[:subject]}"
    msg << "    #{last[:date]}"
    msg << "    #{last[:hash]}"
    msg << ""
    msg << ""
    msg << "Commands:"
    msg << "    #{@options[:testcmd].gsub("\n", "\n    ")}"
    msg << ""
    msg << "Output:"
    msg << ""
    msg << "    #{output.gsub("\n", "\n    ")}"
    msg << ""
    msg << ""
    msg << "-- "
    msg << " Your friendly neighbourhood continues integration annoyer"
    msg << ""

    msg = msg.join "\r\n"

    begin
      Net::SMTP.start('localhost') do |smtp|
        smtp.send_message(
          msg,
          @options[:from],
          @options[:mailto].sub('%a', last[:author]).sub('%c', last[:committer]).split(',')
        )
      end
    rescue => exc
      puts "Error: Unable to send email!"
      puts msg
      raise exc
    end
  end


  def cookie
    "#{@repo}/.git/ci/#{@branch}"
  end


  def verbose msg
    puts "==> #{msg}" if @options[:verbose]
  end
end


def run_for_dir dir='.', options={}
  Dir.entries(dir)
    .select { |d| d.end_with?('.repo') }
    .reject { |d| d.start_with?('.') || !Dir.exists?(d)  }
    .each { |repo| Tester.new(repo, options).start }
end


if __FILE__ == $0
  options = {}
  OptionParser.new do|opts|
    opts.banner = "Usage: #{File.basename $0} [-hVvna] [-m mail1,mail2] [-f from] [dir]"
    opts.on('-v', 'Output more information' ) { options[:verbose] = true }
    opts.on('-n', "Don't actually run tests" ) { options[:dryrun] = true }
    opts.on('-a', "Always run tests, even if the branch hasn't changed") { options[:runalways] = true }
    opts.on('-m',
      'Send email to these addresses; leave blank to disable sending emails. %a and %c can be used as author & committer, respectively') { |m|
      options[:mailto] = m
    }

    opts.on('-f', "From address") { |m| options[:from] = m }

    opts.on('-h', 'Show this help') do
      puts opts
      exit 0
    end

    opts.on('-V', 'Show version') do
      puts '1.0, 2014-04-30'
      exit 0
    end
  end.parse!

  run_for_dir(ARGV.pop || File.dirname(File.realpath(__FILE__)), options)
end


# The MIT License (MIT)
#
# Copyright © 2014 Martin Tournoij
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# The software is provided "as is", without warranty of any kind, express or
# implied, including but not limited to the warranties of merchantability,
# fitness for a particular purpose and noninfringement. In no event shall the
# authors or copyright holders be liable for any claim, damages or other
# liability, whether in an action of contract, tort or otherwise, arising
# from, out of or in connection with the software or the use or other dealings
# in the software.
