define :latex_chroot, :action => :create do
  params[:chroot_root] = params[:name]
  params[:binary_directory] ||= File.join(params[:texlive_directory], "bin/i386-linux")
  params[:chroot_lib_directory] ||= File.join(params[:chroot_root], "lib")
  params[:chroot_bin_directory] ||= File.join(params[:chroot_root], "bin")
  params[:system_binaries] ||= ['sh', 'sed', 'awk', 'uname', 'rm', 'sort', 'mv', 'mkdir', 'grep', 'env', 'chmod', 'cat', 'basename']

  chrooted_texlive_dir = File.join(params[:chroot_root], params[:texlive_directory])
  directory chrooted_texlive_dir do
    owner     params[:owner]
    recursive true
  end

  execute "Copy TeXLive directory to Chroot" do
    command "rsync -a #{File.join(params[:texlive_directory], "/")} #{chrooted_texlive_dir}/"
    creates File.join(chrooted_texlive_dir, "README")
  end

  directory File.join(params[:chroot_root], "tmp") do
    owner params[:owner]
    mode 0777
  end
  directory params[:chroot_lib_directory] do
    owner params[:owner]
  end
  directory params[:chroot_bin_directory] do
    owner params[:owner]
  end

  package "ghostscript"

  ruby_block "Copy libraries and system binaries to Chroot" do
    block do
      def copy_libraries_for_binary(binary_path)
        print "Copying libaries for #{binary_path}\n"
        status, stdout, stderr = systemu(['ldd', binary_path])
        for line in stdout.split("\n") do
          if m = line.match(/^\t.+ => (.+) \(0x.*\)$/)
            library_path = m[1]
          elsif m = line.match(/^\t([^ ]+) \(0x.*\)$/)
            library_path = m[1]
          end

          if library_path
            print " => " + library_path + "\n"
            FileUtils.cp(library_path, params[:chroot_lib_directory])
          end
        end
      end

      def location_of(binary)
        status, stdout, stderr = systemu(['whereis', '-b', binary])
        stdout.split(' ')[1]
      end

      unless File.exist?(File.join(params[:chroot_lib_directory], "/ld-linux.so.2")) 
        binary_names = Dir.entries(params[:binary_directory]).reject{|e| ['.', '..'].include? e}
        for binary_name in binary_names do
          copy_libraries_for_binary(File.join(params[:binary_directory], binary_name))
        end
      end

      unless File.exist?(File.join(params[:chroot_root], "usr/bin")) 
        relative_bin_dir = params[:binary_directory][(params[:chroot_root].length)..-1]
        FileUtils.ln_s(File.join("/", relative_bin_dir), File.join(params[:chroot_root], "usr/bin"))
      end

      unless File.exist?(File.join(params[:chroot_bin_directory], params[:system_binaries][0]))
        for binary_name in params[:system_binaries]
          FileUtils.cp(location_of(binary_name), params[:chroot_bin_directory])
          copy_libraries_for_binary(location_of(binary_name))
        end
      end

      # Install ghostscript and dvipdf (comes with ghostscript) for converting dvi -> pdf
      unless File.exist?(File.join(params[:chroot_bin_directory], "dvipdf"))
        FileUtils.cp(location_of("dvipdf"), params[:chroot_bin_directory])
      end

      unless File.exist?(File.join(params[:chroot_bin_directory], "gs"))
	FileUtils.cp(location_of('gs'), params[:chroot_bin_directory])
	copy_libraries_for_binary(location_of('gs'))

	status, stdout, stderr = systemu(['gs', '-h'])
	directories = stdout.match(/^Search path:\n((?:   .*\n)*)/)[1]
	directories.gsub!("\n", '')
	directories.gsub!(/ *\: */, ':')
	directories.strip!
	directories = directories.split(":")
	directories = directories[1..-1] # remove '.'
	print "Installing ghostscript directories:\n"
	for directory in directories
	  if File.exist?(directory)
	    print directory + "\n"
	    chrooted_directory = File.join(params[:chroot_root], directory)
	    FileUtils.mkdir_p(chrooted_directory)
	    FileUtils.cp_r(directory, File.dirname(chrooted_directory))
	  end
	end
      end

    end
  end
end
