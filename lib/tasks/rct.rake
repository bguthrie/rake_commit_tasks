namespace :rct do
  task "check_ci_status", :url do |t, args|
    cruise_status = CruiseStatus.new(args[:url])
    unless cruise_status.pass? || are_you_sure?( "Build FAILURES: #{cruise_status.failures.join(', ')}" )
      puts "Build is broken; aborting" and exit(1)
    end
  end
  
  def are_you_sure?(message)
    puts "\n", message
    input = ""
    while (input.strip.empty?)
      input = Readline.readline("Are you sure you want to check in? (y/n): ")
    end
    return input.strip.downcase[0,1] == "y"
  end
  
  def sh_with_output(command)
    puts command
    output = `#{command}`
    puts output
    raise unless $?.success?
    output
  end
end
