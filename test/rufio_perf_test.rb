require "test_helper"
require "benchmark/ips"
require "rufio/io"

module Rufio
  class PerfTest < TestCase
    TEMP_BASENAME = "basename"

    context "performance test" do
      should "stuff" do
        {
          "Few large writes in memory" => {
            :max_in_memory_size => 20_000,
            :write_count => 10,
            :write_size => 1000,
          },
          "Few large writes to disk" => {
            :max_in_memory_size => 0,
            :write_count => 10,
            :write_size => 1000,
          },
          "Few large writes to hybrid" => {
            :max_in_memory_size => 2_000,
            :write_count => 10,
            :write_size => 1000,
          },
          "Fewer larger writes in memory" => {
            :max_in_memory_size => 25_000,
            :write_count => 5,
            :write_size => 10000,
          },
          "Fewer larger writes to disk" => {
            :max_in_memory_size => 0,
            :write_count => 5,
            :write_size => 10000,
          },
          "Fewer larger writes to hybrid" => {
            :max_in_memory_size => 5_000,
            :write_count => 5,
            :write_size => 10000,
          },
          "Many small writes in memory" => {
            :max_in_memory_size => 25_000,
            :write_count => 100,
            :write_size => 100,
          },
          "Many small writes to disk" => {
            :max_in_memory_size => 0,
            :write_count => 100,
            :write_size => 100,
          },
          "Many small writes to hybrid" => {
            :max_in_memory_size => 50_000,
            :write_count => 100,
            :write_size => 100,
          },
          "More smaller writes in memory" => {
            :max_in_memory_size => 25_000,
            :write_count => 1000,
            :write_size => 10,
          },
          "More smaller writes to disk" => {
            :max_in_memory_size => 0,
            :write_count => 1000,
            :write_size => 10,
          },
          "More smaller writes to hybrid" => {
            :max_in_memory_size => 50_000,
            :write_count => 1000,
            :write_size => 10,
          },
        }.each_pair.to_a.shuffle.each do |desc, options|
          exec_test(desc, options)
        end
      end
    end

    def benchmark_rufio
      reset_gc
      Benchmark.ips { |bm| bm.report("Rufio::IO") { exec_rufio } }
      nil
    end

    def exec_rufio
      rufio = Rufio::IO.new(TEMP_BASENAME, nil, :max_in_memory_size => @max_in_memory_size)
      rufio.open do |io|
        @count.times { io << @data }
        io.finalize
        assert_equal @expected, io.read
      end
    end

    def benchmark_string
      reset_gc
      Benchmark.ips { |bm| bm.report("String") { exec_string } }
      nil
    end

    def exec_string
      read = ""
      @count.times { read << @data }
      assert_equal @expected, read
    end

    def benchmark_stringio
      reset_gc
      Benchmark.ips { |bm| bm.report("StringIO") { exec_stringio } }
      nil
    end

    def exec_stringio
      io = StringIO.new
      @count.times { io << @data }
      io.rewind
      read = io.read
      assert_equal @expected, read
      nil
    end

    def benchmark_tempfile
      reset_gc
      Benchmark.ips { |bm| bm.report("Tempfile") { exec_tempfile } }
      nil
    end

    def exec_tempfile
      Tempfile.open(TEMP_BASENAME) do |file|
        @count.times { file << @data }
        file.rewind
        assert_equal @expected, file.read
      end
      nil
    end

    def exec_test(desc, options)
      @count = options[:write_count]
      @size = options[:write_size]
      @max_in_memory_size = options[:max_in_memory_size]
      @data = ("a" * @size).freeze
      @expected = (@data * @count).freeze

      puts ("*** " << desc) << "\n"
      benchmark_tempfile
      benchmark_rufio
      benchmark_string
      benchmark_stringio
    end

    def reset_gc
      GC.start
    end
  end
end
