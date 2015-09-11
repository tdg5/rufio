# The Rufio gem namespace.
module Rufio
  # A library for streaming I/O that prefers to store data in memory, but will
  # fall back to storing the data in a Tempfile once the data reaches a minimum
  # size.
  class IO

    class << self
      # Default max in memory size is 250MB.
      DEFAULT_MAX_IN_MEMORY_SIZE = 250_000_000

      # Sets the default value that should be used for `max_in_memory_size` of
      # IO instances.
      attr_writer :default_max_in_memory_size

      # Returns the default value that should be used for `max_in_memory_size`
      # of IO instances.
      def default_max_in_memory_size
        @default_max_in_memory_size || DEFAULT_MAX_IN_MEMORY_SIZE
      end
    end

    # The maximum amount of data in bytes that will be retained before writing
    # subsequent data to disk.
    attr_reader :max_in_memory_size

    # The size in bytes of the IO object.
    attr_reader :size

    # Creates a new instance of the `Rufio::IO` class. Other than the
    # `max_in_memory_size` option, all other arguments are used to initialize a
    # Tempfile instance if it should become necessary.
    #
    # @param [String] basename The basename parameter is used to determine the
    #   name of the temporary file. You can either pass a String or an Array
    #   with 2 String elements. In the former form, the temporary file’s base
    #   name will begin with the given string. In the latter form, the temporary
    #   file’s base name will begin with the array’s first element, and end with
    #   the second element.
    # @param [String] tmpdir The temporary file will be placed in the directory
    #   as specified by the tmpdir parameter. By default, this is Dir.tmpdir.
    #   When $SAFE > 0 and the given tmpdir is tainted, it uses ‘/tmp’ as the
    #   temporary directory. Please note that ENV values are tainted by default,
    #   and Dir.tmpdir‘s return value might come from environment variables
    #   (e.g.  $TMPDIR).
    # @param [Hash] options Under the hood, Rufio uses Tempfile and Tempfile
    #   creates temporarys file using File.open. These options will be passed to
    #   File.open. This is mostly useful for specifying encoding and other
    #   similar options. By default, no options are used.
    def initialize(basename, tmpdir = nil, options = nil)
      @basename = basename
      @tmpdir = tmpdir || Dir.tmpdir
      @open_options = options.nil? ? {} : options.dup
      @max_in_memory_size = @open_options.delete(:max_in_memory_size) ||
        self.class.default_max_in_memory_size

      @in_memory = true
      @open = false
      @finalized = false
      @io = StringIO.new
      @size = 0
      open(&Proc.new) if block_given?
    end

    # Returns a boolean indicating whether the IO object has been finalized.
    #
    # @return [Boolean] Returns true if the IO has been finalized and false if
    #   the IO has not yet been finalized.
    def final?
      !!@finalized
    end

    # Finalizes the IO object such that no further writes are allowed.
    #
    # @raise [IOError] when the stream is closed or already final.
    # @return [true] Returns true when successful.
    def finalize
      raise IOError, "closed stream" if !open?
      raise IOError, "I/O finalized!" if final?
      @io.rewind
      @finalized = true
    end

    # Returns a boolean indicating whether or not data written to the IO is
    # being stored in memory.
    #
    # @return [Boolean] Returns true if the IO is stored in memory. Returns
    #   false if the IO has switched to writing to disk.
    def in_memory?
      !!@in_memory
    end

    # Opens the IO object for use.
    def open
      raise(RuntimeError, "Already open") if open?
      raise(ArgumentError, "Block required!") unless block_given?
      @open = true
      yield self
    ensure
      @open = false
      @io.close if !in_memory?
    end

    # Returns a boolean indicating whether or not the IO object is open for use.
    #
    # @return [Boolean] Returns true if the IO object is open and returns false
    #   if the IO is not open.
    def open?
      !!@open
    end

    # Returns the position of the IO cursor.
    #
    # @return [Integer] The byte offset of the IO cursor's position.
    def pos
      raise IOError, "closed stream" if !open?
      @io.pos
    end

    # Reads data from the IO object. All arguments are passed to the underlying
    # IO object.
    #
    # @raise [IOError] when the IO is closed or is not final.
    # @return [String] Returns the requested read.
    def read(*args)
      raise IOError, "closed stream" if !open?
      raise IOError, "I/O not finalized!" if !final?
      @io.read(*args)
    end

    # Appends the given chunk of data to the IO object.
    #
    # @param [String] chunk The data to write to the IO object.
    # @return [String] The provided chunk of data is returned.
    def write(chunk)
      raise IOError, "closed stream" if !open?
      raise IOError, "I/O finalized!" if final?
      @size += chunk.bytesize
      update_io
      @io << chunk
      chunk
    end
    alias_method(:<<, :write)

    protected

    # Helper to create and unlink the Tempfile.
    def create_tempfile
      io = Tempfile.new(@basename, @tmpdir, @open_options)
      io.unlink
      io
    end

    # Helper to transfer the written data from the in-memory IO object to the
    # Tempfile IO object.
    def transfer_io(src_io, dest_io)
      src_io.rewind
      dest_io << src_io.read
      true
    end

    # Helper called before each write to check if the IO object should be
    # transitioned from in-memory to on disk.
    def update_io
      # Worth noting that size always appears larger during this check than it
      # is in reality since the size is updated prior to writing out the data to
      # ensure that the amount of data stored in RAM doesn't exceed the maximum
      # in memory size.
      return if !in_memory? || size <= max_in_memory_size
      @in_memory = false
      io = create_tempfile
      transfer_io(@io, io)
      @io = io
      nil
    end
  end
end
