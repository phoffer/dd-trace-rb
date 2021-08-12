# typed: true
return unless __FILE__ == $PROGRAM_NAME

require 'benchmark/ips'
require 'ddtrace'
require 'pry'

# This benchmark measures the performance of encoding pprofs and trying to submit them
#
# The FLUSH_DUMP_FILE (by default benchmarks/data/profiler-submission-marshal.gz, gathered from benchmarking using
# the discourse forum rails app) can be generated by changing the scheduler.rb#flush_events to dump the contents of
# "flush" to a file during a benchmark execution:
#
# dump_file = "marshal-#{Time.now.utc.to_i}.dump"
# File.open(dump_file, "w") { |f| Marshal.dump(flush, f) }
# Datadog.logger.info("Dumped to #{dump_file}")
#
# And then gzipping the result. (This can probably be automated a bit by adding an extra exporter, but the above worked
# for me).

class ProfilerSubmission
  def create_profiler
    @adapter_buffer = []

    Datadog.configure do |c|
      # c.diagnostics.debug = true
      c.profiling.enabled = true
      c.tracer.transport_options = proc { |t| t.adapter :test, @adapter_buffer }
    end

    # Stop background threads
    Datadog.profiler.shutdown!

    # Call exporter directly
    @exporter = Datadog.profiler.scheduler.exporters.first
    @flush = Marshal.load(
      Zlib::GzipReader.new(File.open(ENV['FLUSH_DUMP_FILE'] || 'benchmarks/data/profiler-submission-marshal.gz'))
    )
  end

  def check_valid_pprof
    output_pprof = @adapter_buffer.last[:form]["data[0]"].io

    expected_hashes = [
      "cf2d47ce25f3d2541327ab509ca7bfb6a3a0aa30ce18a428cbcc476e4e137878",
    ]
    current_hash = Digest::SHA256.hexdigest(Zlib::GzipReader.new(output_pprof).read)

    if expected_hashes.include?(current_hash)
      puts "Output hash #{current_hash} matches known signature"
    else
      puts "WARNING: Unexpected pprof output -- unknown hash (#{current_hash}). Hashes seem to differ due to some of our dependencies changing, " \
        "but it can also indicate that encoding output has become corrupted."
    end
  end

  def run_benchmark
    Benchmark.ips do |x|
      x.config(time: 10, warmup: 2)

      x.report("exporter #{ENV['CONFIG']}") do
        run_once
      end

      x.save! 'profiler-submission-results.json'
      x.compare!
    end
  end

  def run_forever
    while true
      run_once
      print '.'
    end
  end

  def run_once
    @adapter_buffer.clear
    @exporter.export(@flush)
  end
end

puts "Current pid is #{Process.pid}"

ProfilerSubmission.new.instance_exec do
  create_profiler
  run_once
  check_valid_pprof

  if ARGV.include?('--forever')
    run_forever
  else
    run_benchmark
  end
end
