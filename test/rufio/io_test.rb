require "test_helper"
require "rufio/io"

module Rufio
  class IOTest < TestCase
    DUMMY_BASENAME = "basename".freeze

    Subject = Rufio::IO

    context "::default_max_in_memory_size=" do
      subject { Subject }

      # Implicitly tests IO.default_max_in_memory_size
      should "set the default maximum in memory size" do
        # Ensure default is restored in the event of test failure
        initial_default = subject.default_max_in_memory_size
        begin
          new_default = initial_default * 2
          subject.default_max_in_memory_size = new_default
          assert_equal new_default, subject.default_max_in_memory_size
        ensure
          subject.default_max_in_memory_size = initial_default
        end
      end
    end

    context "#initialize" do
      subject { Subject }

      should "require a basename" do
        assert_raises(ArgumentError) { subject.new }
      end

      should "use the default_max_in_memory_size when no value is provided" do
        default = subject.default_max_in_memory_size
        assert_equal default, subject.new(DUMMY_BASENAME).max_in_memory_size
      end

      should "use the provided max_in_memory_size when a value is provided" do
        max_size = 250
        instance = subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => max_size)
        assert_equal max_size, instance.max_in_memory_size
      end
    end

    context "#final?" do
      subject { Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 50) }

      should "return true when the IO is finalized" do
        subject.open do |io|
          io << "a"
          io.finalize
          assert_equal true, io.final?
        end
      end

      should "return false when the IO is not finalized" do
        subject.open do |io|
          io << "a"
          assert_equal false, io.final?
        end
      end
    end

    context "#finalize" do
      subject { Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 5) }

      should "rewind a tempfile backed IO" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          subject.open do |io|
            chunk = "aaaa" * 2
            io << chunk
            io.finalize
            assert_equal 0, tmpfile.pos
          end
        end
      end

      should "cause #final? to return true" do
        subject.open do |io|
          io << "a"
          io.finalize
          assert_equal true, io.final?
        end
      end
    end

    context "#in_memory?" do
      should "return true only after data is being written to disk" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 30)
          instance.open do |io|
            instance.expects(:create_tempfile).never
            5.times { io << "hello" }
            assert_equal true, io.in_memory?
            io << "hello"
            assert_equal true, io.in_memory?

            instance.expects(:create_tempfile).returns(tmpfile)
            io << "hello"
            assert_equal false, io.in_memory?
          end
        end
      end
    end

    context "#open" do
      subject { Subject.new(DUMMY_BASENAME) }

      should "raise error if no block is given" do
        assert_raises(ArgumentError) { subject.open }
      end

      should "raise error if the IO is already open" do
        assert_raises(RuntimeError) { subject.open { |io| io.open } }
      end

      should "open the io and yield it to the provided block" do
        subject.open do |io|
          assert_equal subject, io
          assert_equal true, subject.open?
        end
      end

      should "cause #open? to return true" do
        subject.open { |io| assert_equal true, subject.open? }
      end

      should "ensure an open Tempfile is closed" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, Dir.tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 1)
          instance.open { |io| io << "hello" }
          assert_equal true, tmpfile.closed?
        end
      end

      should "ensure an open Tempfile is closed when an error is raised" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, Dir.tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 1)
          begin
            instance.open do |io|
              io << "hello"
              assert_equal false, io.in_memory?
              raise RuntimeError
            end
          rescue RuntimeError
          end
          assert_equal true, tmpfile.closed?
        end
      end
    end

    context "#open?" do
      subject { Subject.new(DUMMY_BASENAME) }

      should "return true when the IO is open" do
        subject.open { |io| assert_equal true, subject.open? }
      end

      should "return false when the IO is not open" do
        assert_equal false, subject.open?
      end
    end

    context "#read" do
      subject { Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 30) }

      should "raise IOError if the IO isn't open" do
        assert_raises(IOError) { subject.read }
      end

      should "raise IOError if the IO isn't finalized" do
        assert_raises(IOError) do
          subject.open do |io|
            io.read
          end
        end
      end

      should "read the specified number of bytes when in memory" do
        data = "hello" * 4
        subject.open do |io|
          io << data
          assert_equal true, io.in_memory?
          io.finalize
          assert_equal data[0..19], io.read(20)
        end
      end

      should "read the specified number of bytes when using tempfile" do
        data = "hello" * 8
        subject.open do |io|
          io << data
          assert_equal false, io.in_memory?
          io.finalize
          assert_equal data[0..19], io.read(20)
        end
      end
    end

    context "#write" do
      subject { Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 50) }

      should "raise IOError if the IO isn't open" do
        assert_raises(IOError) { subject.write("hello") }
      end

      should "raise IOError if the IO is finalized" do
        assert_raises(IOError) do
          subject.open do |io|
            io.finalize
            subject.write("hello")
          end
        end
      end

      should "write the chunk of data to the io object" do
        chunk = "a" * 25
        subject.open do |io|
          io.write(chunk)
          io.finalize
          assert_equal chunk, io.read
        end
      end
    end

    context "IO switch" do
      should "not switch until in memory size exceeds max in memory size" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 30)
          instance.open do |io|
            instance.expects(:create_tempfile).never
            6.times { io << "hello" }
            assert_equal io.size, io.max_in_memory_size

            instance.expects(:create_tempfile).returns(tmpfile)
            2.times { io << "hello" }
          end
        end
      end

      should "pass Dir.tmpdir for tmpdir by default" do
        tmpdir = Dir.tmpdir
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 1)
          instance.open { |io| io << "hello" }
        end
      end

      should "pass the expected tmpdir to Tempfile.new if a tmpdir was provided" do
        tmpdir = "/"
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, tmpdir, :max_in_memory_size => 1)
          instance.open { |io| io << "hello" }
        end
      end

      # Implicitly tests that :max_in_memory_size is correctly removed from the
      # options Hash.
      should "pass no File.open options to Tempfile by default" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, Dir.tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 1)
          instance.open { |io| io << "hello" }
        end
      end

      should "unlink the new tempfile" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          Tempfile.expects(:new).with(DUMMY_BASENAME, Dir.tmpdir, {}).returns(tmpfile)
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 1)
          refute_nil tmpfile.path
          instance.open { |io| io << "hello" }
          assert_nil tmpfile.path
        end
      end

      should "copy data from in-memory representation to tempfile" do
        Tempfile.open(DUMMY_BASENAME) do |tmpfile|
          instance = Subject.new(DUMMY_BASENAME, nil, :max_in_memory_size => 30)
          instance.open do |io|
            instance.expects(:create_tempfile).never
            6.times { io << "hello" }
            instance.expects(:create_tempfile).returns(tmpfile)
            2.times { io << "hello" }
            io.finalize
            assert_equal("hello" * 8, io.read)
          end
        end
      end
    end
  end
end
