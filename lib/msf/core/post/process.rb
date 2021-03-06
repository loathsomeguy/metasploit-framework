module Msf::Post::Process

  include Msf::Post::File

  def initialize(info = {})
    super(update_info(
      info,
      'Compat' => { 'Meterpreter' => { 'Commands' => %w{
        stdapi_sys_process_get_processes
      } } }
    ))
  end

  #
  # Checks if the remote system has a process with ID +pid+
  #
  def has_pid?(pid)
    pid_list = get_processes.collect { |e| e['pid'] }
    pid_list.include?(pid)
  end

  def get_processes
    if session.type == 'meterpreter'
      return session.sys.process.get_processes.map { |p| p.slice('name', 'pid') }
    end
    processes = []
    if session.platform == 'windows'
      tasklist = cmd_exec('tasklist').split("\n")
      4.times { tasklist.delete_at(0) }
      tasklist.each do |p|
        properties = p.split
        process = {}
        process['name'] = properties[0]
        process['pid'] = properties[1].to_i
        processes.push(process)
      end
      # adding manually because this is common for all windows I think and splitting for this was causing problem for other processes.
      processes.prepend({ 'name' => '[System Process]', 'pid' => 0 })
    else
      if command_exists?('ps')
        ps_aux = cmd_exec('ps aux').split("\n")
        ps_aux.delete_at(0)
        ps_aux.each do |p|
          properties = p.split
          process = {}
          process['name'] = properties[10].gsub(/\[|\]/,"")
          process['pid'] = properties[1].to_i
          processes.push(process)
        end
      elsif directory?('/proc')
        directories_proc = dir('/proc/')
        directories_proc.each do |elem|
          elem.to_s.gsub(/ *\n+/, '')
          next unless elem[-1].match? /\d/

          process = {}
          process['pid'] = elem.to_i
          status = read_file("/proc/#{elem}/status") # will return nil if the process `elem` PID got vanished
          next unless status

          process['name'] = status.split(/\n|\t/)[1]
          processes.push(process)
        end
      else
        raise "Can't enumerate processes because `ps' command and `/proc' directory doesn't exist."
      end
    end
    return processes
  end


end
