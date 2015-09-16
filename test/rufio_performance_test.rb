require "test_helper"
require "benchmark/ips"
require "securerandom"
require "rufio/io"

module Rufio
  class PerfTest < TestCase
    TEMP_BASENAME = "temp-basename"
    BYTES_10 = SecureRandom.random_bytes(10)
    BYTES_100 = SecureRandom.random_bytes(100)
    BYTES_1000 = SecureRandom.random_bytes(1000)
    BYTES_10000 = SecureRandom.random_bytes(10000)

    TEST_CASES = {
      "10 writes of 10 bytes" => {
        :count => 10,
        :data => BYTES_10,
      },
      "100 writes of 10 bytes" => {
        :count => 100,
        :data => BYTES_10,
      },
      "1000 writes of 10 bytes" => {
        :count => 1000,
        :data => BYTES_10,
      },
      "10000 writes of 10 bytes" => {
        :count => 10000,
        :data => BYTES_10,
      },
      "10 writes of 100 bytes" => {
        :count => 10,
        :data => BYTES_100,
      },
      "100 writes of 100 bytes" => {
        :count => 100,
        :data => BYTES_100,
      },
      "1000 writes of 100 bytes" => {
        :count => 1000,
        :data => BYTES_100,
      },
      "10000 writes of 100 bytes" => {
        :count => 10000,
        :data => BYTES_100,
      },
      "10 writes of 1000 bytes" => {
        :count => 10,
        :data => BYTES_1000,
      },
      "100 writes of 1000 bytes" => {
        :count => 100,
        :data => BYTES_1000,
      },
      "1000 writes of 1000 bytes" => {
        :count => 1000,
        :data => BYTES_1000,
      },
      "10000 writes of 1000 bytes" => {
        :count => 10000,
        :data => BYTES_1000,
      },
      "10 writes of 10000 bytes" => {
        :count => 10,
        :data => BYTES_10000,
      },
      "100 writes of 10000 bytes" => {
        :count => 100,
        :data => BYTES_10000,
      },
      "1000 writes of 10000 bytes" => {
        :count => 1000,
        :data => BYTES_10000,
      },
      "10000 writes of 10000 bytes" => {
        :count => 10000,
        :data => BYTES_10000,
      },
    }

    context "Comparative benchmarks" do
      context "Rufio" do
        TEST_CASES.each do |desc, options|
          [1, 10, 100].each do |percent_in_memory|
            rufio_desc = desc + " - #{percent_in_memory}% in memory"
            should rufio_desc do
              count, data = options.values_at(:count, :data)
              expected_data = data * count
              max_in_memory_size = expected_data.size * percent_in_memory / 100
              opts = { :max_in_memory_size => max_in_memory_size }
              benchmark_rufio(rufio_desc, count, data, expected_data, opts)
            end
          end
        end
      end

      context "String" do
        TEST_CASES.each do |desc, options|
          should desc do
            count, data = options.values_at(:count, :data)
            expected_data = data * count
            benchmark_string(desc, count, data, expected_data)
          end
        end
      end

      context "StringIO" do
        TEST_CASES.each do |desc, options|
          should desc do
            count, data = options.values_at(:count, :data)
            expected_data = (data * count).force_encoding("ascii-8bit")
            benchmark_stringio(desc, count, data, expected_data)
          end
        end
      end

      context "Tempfile" do
        TEST_CASES.each do |desc, options|
          should desc do
            count, data = options.values_at(:count, :data)
            expected_data = data * count
            benchmark_tempfile(desc, count, data, expected_data)
          end
        end
      end
    end

    private

    def bench(io, count, data, expected_data)
      count.times { io << data }
      io.rewind
      assert_equal expected_data, io.read.force_encoding("ascii-8bit")
      nil
    end

    def bench_string(str, count, data, expected_data)
      count.times { str << data }
      # Force encoding probably not required, but included for parity.
      assert_equal expected_data, str.force_encoding("ascii-8bit")
      nil
    end

    def benchmark_rufio(desc, count, data, expected_data, rufio_opts = {})
      reset_gc
      Benchmark.ips do |bm|
        bm.report("Rufio::IO - #{desc}") do
          Rufio::IO.new(TEMP_BASENAME, nil, rufio_opts) do |rufio|
            bench(rufio, count, data, expected_data)
          end
        end
      end
    end

    def benchmark_string(desc, count, data, expected_data)
      reset_gc
      Benchmark.ips do |bm|
        bm.report("String - #{desc}") do
          bench_string("", count, data, expected_data)
        end
      end
    end

    def benchmark_stringio(desc, count, data, expected_data)
      reset_gc
      Benchmark.ips do |bm|
        bm.report("StringIO - #{desc}") do
          io = StringIO.new
          io.binmode
          bench(io, count, data, expected_data)
        end
      end
    end

    def benchmark_tempfile(desc, count, data, expected_data)
      reset_gc
      Benchmark.ips do |bm|
        bm.report("Tempfile - #{desc}") do
          Tempfile.open(TEMP_BASENAME) do |tempfile|
            tempfile.binmode
            bench(tempfile, count, data, expected_data)
          end
        end
      end
    end

    def reset_gc
      GC.start
    end
  end
end
