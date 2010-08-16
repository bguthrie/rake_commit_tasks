require 'readline'
require 'tmpdir'
require 'rexml/document'
require 'open-uri'
require 'rake'
require 'rake/tasklib'

Dir[File.dirname(__FILE__) + "/tasks/**/*.rake"].each { |rakefile| load rakefile }

class RakeCommitTask < Rake::TaskLib
  attr_accessor :name
  attr_accessor :test_task
  attr_writer :scm
  attr_reader :ccrb_url, :prompts
  
  DEFAULT_PROMPTS = [ "pair", "feature", "message" ]

  def initialize(name)
    @name = name
    @test_task = :default
    @prompts = []
    yield self if block_given?
    define
    @prompts = DEFAULT_PROMPTS if @prompts.empty?
  end

  def prompt_for(attribute)
    @prompts << attribute
  end

  def scm
    @scm ||= determine_scm
  end

  def ci_configured?
    !!@ccrb_rss
  end

  # 1 - Prompt for commit message
  # 2 - Run precommit (may include cleanup, staging, local repo checkin)
  # 3 - Run the pre-commit test task, as specified (defaults to :default)
  # 4 - Check for CCRB status
  # 5 - Perform the commit (may include local repo checkin, must include remote repo checkin)
  # 6 - Run postcommit/cleanup (may include anything)
  def define
    desc("Prompt for commit message, run tests, and commit to the repo") unless ::Rake.application.last_comment
    task name do
      commit_message = CommitMessage.new(prompts, PropertyStore.for(scm)).generate
      
      Rake::Task["rct:#{scm}:precommit"].invoke(commit_message)
      Rake::Task[test_task].invoke
      Rake::Task["rct:check_ci_status"].invoke(ccrb_url) if ci_configured?
      Rake::Task["rct:#{scm}:commit"].invoke(commit_message)
      # Rake::Task["rct:#{scm}:postcommit"].invoke
    end
  end
  
  class CruiseStatus

    def initialize(feed_url)
      project_feed = open(feed_url).read
      @doc = REXML::Document.new(project_feed)
    rescue Exception => e
      @failures = [e.message]
      @doc = REXML::Document.new("")
    end

    def pass?
      failures.empty?
    end

    def failures
      @failures ||= REXML::XPath.match(@doc, "//item/title").select { |element|
        element.text =~ /failed$/
      }.map do |element|
        element.text.gsub( /(.*) build (.+) failed$/, '\1' )
      end
    end
    
  end
  
  class PromptLine

    def initialize(attribute, store_class)
      @attribute = attribute
      @store = store_class.new(attribute)
    end

    def prompt
      input = nil
      loop do
        input = Readline.readline(message).chomp
        break unless (input.empty? && @store.read.empty?)
      end

      if input.any?
        @store.write(input)
        return input
      end

      puts "using: #{@store.read}"
      return @store.read
    end

    def message
      message = "\n"
      message += "previous #{@attribute}: #{@store.read}\n" unless @store.empty?
      message + "#{@attribute}: "
    end

  end

  class PropertyStore
    attr_reader :attribute
    
    def initialize(attribute)
      @attribute = attribute
    end
    
    def empty?
      read.nil? || read.empty?
    end
    
    def read; raise; end
    def write(value); raise; end
    
    class << self
      def for(scm)
        scm == :svn ? RakeCommitTask::FilePropertyStore : RakeCommitTask::GitPropertyStore
      end
    end
  end
  
  class GitPropertyStore < PropertyStore
    def read
      @val ||= `git config commit.#{attribute}`
    end
    
    def write(value)
      @val = value
      `git config commit.#{attribute} #{value.inspect}`
    end
  end
  
  class FilePropertyStore < PropertyStore
    def read
      @val ||= File.exists?(path) ? File.read(path) : ""
    end
    
    def write(value)
      @val = value
      File.open(path, "w") { |f| f.write(value) }
    end
    
    private
    
      def path
        File.expand_path(Dir.tmpdir + "/#{attribute}.data")
      end
  end
  
  class CommitMessage
    attr_reader :prompts

    def initialize(prompts, store_class)
      @prompts = prompts
      @store_class = store_class
    end

    def generate
      self.prompts.map do |attribute|
        PromptLine.new(attribute, @store_class).prompt
      end.join(' - ')
    end
  end

  private

    def determine_scm
      if git?
        :git
      elsif git_svn?
        :git_svn
      else
        :svn
      end
    end

    def git?
      `git symbolic-ref HEAD 2>/dev/null`
      $?.success?
    end

    def git_svn?
      `git svn info 2> /dev/null`
      $?.success?
    end

end
