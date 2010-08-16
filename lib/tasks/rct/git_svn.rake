namespace :rct do
  namespace :git_svn do
    desc "rebase with the main svn repo"
    task :rebase do
      sh "git svn rebase"
    end

    desc "dcommit to main svn repo"
    task :dcommit do
      sh "git svn dcommit"
    end
    
    task :precommit, [:message] => ['rct:git:add', 'rct:git:st', 'rct:git_svn:commit_with_message', 'rct:git_svn:rebase']
    task :commit     => ['rct:git_svn:dcommit']
    task :postcommit => []

    task :commit_with_message => ['rct:git:commit_with_message']

    # desc "use to commit manually added changes to staging"
    # task :commit_local do
    #   git_svn_commit_with_message
    # end
  end
end
