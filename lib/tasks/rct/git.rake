namespace :rct do
  namespace :git do
    desc "display git status"
    task :st do
      sh "git status"
    end

    desc "add files to git index"
    task :add do
      sh "git add -A ."
    end

    desc "reset soft back to common ancestor of branch and origin/branch"
    task :reset_soft do
      raise "Could not determine branch" unless git_branch
      sh "git reset --soft #{merge_base}"
    end

    desc "pull from origin and rebase to keep a linear history"
    task :pull_rebase do
      sh "git pull --rebase"
    end

    desc "push to origin"
    task :push do
      sh "git push origin #{git_branch}"
    end
    
    desc "configure with a particular value"
    task :config, [:property, :value] do |t, args|
      sh "git config #{property} #{value}"
    end
    
    task :precommit, [:message] => ['rct:git:collapse_commits', 'rct:git:commit_with_message', 'rct:git:pull_rebase']
    task :commit => ['rct:git:push']
    task :postcommit => []

    task :commit_with_message, [:message] do |t, args|
      sh_with_output("git commit -m \"#{args[:message]}\"")
    end

    task :collapse_commits do
      if !has_merge_commits? || need_to_collapse_merge_commits?
        Rake::Task["rct:git:reset_soft"].execute
        Rake::Task["rct:git:add"].execute
        Rake::Task["rct:git:st"].invoke
      else
        puts "Nothing to commit" and exit(1)
      end
    end
  end
  
  def need_to_collapse_merge_commits?
    Rake::Task["rct:git:st"].execute
    input = Readline.readline("Do you want to collapse merge commits? (y/n): ").chomp
    input == "y"
  end

  def git_branch
    output = `git symbolic-ref HEAD`
    return nil unless $?.success?
    output.gsub('refs/heads/', '').strip
  end

  def has_merge_commits?
    `git log --merges #{merge_base}..HEAD`.any?
  end

  def merge_base
    `git merge-base #{git_branch} origin/#{git_branch}`.strip
  end
end

