# RFuseFS.rb
require 'fuse/fusedir'
require 'fuse/rfusefs-fuse'
require 'rfusefs/version'

# This is FuseFS compatible module built over RFuse

module FuseFS
    @mounts = { }

    # Start the FuseFS root at mountpoint with opts. 
    # @param [Object] root see {set_root}
    # @param mountpoint [String] {mount_under}
    # @param [String...] opts FUSE mount options see {mount_under}
    # @note RFuseFS extension
    # @return [void]
    def FuseFS.start(root,mountpoint,*opts)
        print "Starting FuseFS #{root} at #{mountpoint} with #{opts}\n"
        Signal.trap("TERM") { FuseFS.exit() }
        Signal.trap("INT") { FuseFS.exit() }
        FuseFS.set_root(root)
        FuseFS.mount_under(mountpoint,*opts)
        FuseFS.run
        FuseFS.unmount()
    end

    # Forks {FuseFS.start} so you can access your filesystem with ruby File
    # operations (eg for testing). 
    # @note This is an *RFuseFS* extension
    # @return [void]
    def FuseFS.mount(root,mountpoint,*opts)

        pid = Kernel.fork do
            FuseFS.start(root,mountpoint,*opts)
        end
        @mounts[mountpoint] = pid
        pid
    end

    # Unmount a filesystem
    # @param mountpoint [String] If nil?, unmounts the filesystem started with {start}
    #                            otherwise signals the forked process started with {mount}
    #                            to exit and unmount.
    # @note RFuseFS extension
    # @return [void]
    def FuseFS.unmount(mountpoint=nil)

        if (mountpoint)
            if @mounts.has_key?(mountpoint)
                pid = @mounts[mountpoint]
                print "Sending TERM to forked FuseFS (#{pid})\n"
                Process.kill("TERM",pid)
                Process.waitpid(pid)
            else
                raise "Unknown mountpoint #{mountpoint}"
            end
        else
            #Local unmount, make sure we only try to unmount once
            if @fuse && @fuse.mounted?
                print "Unmounting #{@fuse.mountname}\n"
                @fuse.unmount()
            end
            @fuse = nil
        end
    end

    # Set the root virtual directory 
    # @param root [Object] an object implementing a subset of {FuseFS::API}
    # @return [void]
    def FuseFS.set_root(root)
        @fs=RFuseFS.new(root)
    end

    # This will cause FuseFS to virtually mount itself under the given path. {set_root} must have
    # been called previously.
    # @param [String] mountpoint an existing directory where the filesystem will be virtually mounted
    # @param [Array<String>] args
    #  These are as expected by the "mount" command. Note in particular that the first argument
    #  is expected to be the mount point. For more information, see http://fuse.sourceforge.net
    #  and the manual pages for "mount.fuse"
    def FuseFS.mount_under(mountpoint, *args)    
        @fuse = RFuse::FuseDelegator.new(@fs,mountpoint,*args)
    end

    # This is the main loop waiting on then executing filesystem operations from the
    # kernel. 
    #    
    # Note: Running in a separate thread is generally not useful. In particular
    #       you cannot access your filesystem using ruby File operations.
    # @note RFuseFS extension
    def FuseFS.run
        @fuse.loop if @fuse.mounted? 
    end

    #  Exit the run loop and teardown FUSE   
    #  Most useful from Signal.trap() or Kernel.at_exit()  
    def FuseFS.exit
        @running = false

        if @fuse
            print "Exitting FUSE #{@fuse.mountname}\n"
            @fuse.exit
        end
    end

    # @return [Fixnum] the calling process uid
    #     You can use this in determining your permissions, or even provide different files
    #     for different users.
    def self.reader_uid
        Thread.current[:fusefs_reader_uid]
    end

    # @return [Fixnum] the calling process gid
    def self.reader_gid
        Thread.current[:fusefs_reader_gid]
    end

    # Not supported in RFuseFS (yet). The original FuseFS had special handling for editor
    # swap/backup but this does not seem to be required, eg for the demo filesystems.
    # If it is required it can be implemented in a filesystem
    # @deprecated
    def self.handle_editor(bool)
        #do nothing
    end
end

