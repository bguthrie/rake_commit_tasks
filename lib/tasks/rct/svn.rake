namespace :rct do
  namespace :svn do
    desc "display svn status"
    task :st do
      puts %x[svn st]
    end

    desc "svn up and check for conflicts"
    task :up do
      output = %x[svn up]
      puts output
      output.each do |line|
        raise "SVN conflict detected. Please resolve conflicts before proceeding." if line[0,1] == "C"
      end
    end

    desc "add new files to svn"
    task :add do
      %x[svn st].split("\n").each do |line|
        if new_file?(line) && !svn_conflict_file?(line)
          file = line[7..-1].strip
          %x[svn add #{file.inspect}]
          puts %[added #{file}]
        end
      end
    end

    def new_file?(line)
      line[0,1] == "?"
    end

    def svn_conflict_file?(line)
      line =~ /\.r\d+$/ || line =~ /\.mine$/
    end

    desc "remove deleted files from svn"
    task :delete do
      %x[svn st].split("\n").each do |line|
        if line[0,1] == "!"
          file = line[7..-1]
          %x[svn up #{file.inspect} && svn rm #{file.inspect}]
          puts %[removed #{file}]
        end
      end
    end
    task :rm => "rct:svn:delete"

    desc "reverts all files in svn and deletes new files"
    task :revert_all do
      system "svn revert -R ."
      %x[svn st].split("\n").each do |line|
        next unless line[0,1] == '?'
        filename = line[1..-1].strip
        puts "removed #{filename}"
        rm_r filename
      end
    end

    def merge_to_trunk(revision)
      puts "Merging changes into trunk.  Don't forget to check these in."
      sh "svn up #{PATH_TO_TRUNK_WORKING_COPY.inspect}"
      sh "svn merge -c #{revision} . #{PATH_TO_TRUNK_WORKING_COPY.inspect}"
    end
    
    task :precommit => ['rct:svn:add', 'rct:svn:delete', 'rct:svn:up']
    task :commit, [:message] => ['svn:st'] do |t, args|
      if files_to_check_in?
        output = sh_with_output "#{commit_command(message)}"
        revision = output.match(/Committed revision (\d+)\./)[1]
        merge_to_trunk(revision) if system("svn info").include?("branches") && self.class.const_defined?(:PATH_TO_TRUNK_WORKING_COPY)        
      else
        puts "Nothing to commit" and exit(1)
      end
    end
    
    task :postcommit => []
  
    def commit_command(message)
      "svn ci -m #{message.inspect}"
    end
  
    def files_to_check_in?
      %x[svn st --ignore-externals].split("\n").reject {|line| line[0,1] == "X"}.any?
    end
  end
end
