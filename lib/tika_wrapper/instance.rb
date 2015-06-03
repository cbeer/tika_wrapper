require 'digest'
require 'fileutils'
require 'json'
require 'open-uri'
require 'ruby-progressbar'
require 'securerandom'
require 'stringio'
require 'tmpdir'

module TikaWrapper
  class Instance
    attr_reader :options, :pid

    ##
    # @param [Hash] options
    # @option options [String] :url
    # @option options [String] :version
    # @option options [String] :port
    # @option options [String] :version_file
    # @option options [String] :instance_dir
    # @option options [String] :download_path
    # @option options [String] :md5sum
    # @option options [String] :tika_xml
    # @option options [Boolean] :verbose
    # @option options [Boolean] :managed
    # @option options [Boolean] :ignore_md5sum
    # @option options [Hash] :tika_options
    # @option options [Hash] :env
    def initialize(options = {})
      @options = options
    end

    def wrap(&_block)
      start
      yield self
    ensure
      stop
    end

    ##
    # Start tika and wait for it to become available
    def start
      download
      if managed?
        exec(p: port)

        # Wait for tika to start
        unless status
          sleep 1
        end
      end
    end

    ##
    # Stop tika and wait for it to finish exiting
    def stop
      if managed? && started?
        Process.kill("KILL", pid.to_i)

        # Wait for tika to stop
        while status
          sleep 1
        end
      end

      @pid = nil
    end

    ##
    # Check the status of a managed tika service
    def status
      return true unless managed?

      begin
        open(url + "version")
        true
      rescue
        false
      end
    end

    ##
    # Is tika running?
    def started?
      !!status
    end

    ##
    # Get the port this tika instance is running at
    def port
      options.fetch(:port, "9998").to_s
    end

    ##
    # Clean up any files tika_wrapper may have downloaded
    def clean!
      stop
      FileUtils.remove_entry(download_path) if File.exists? download_path
      FileUtils.remove_entry(md5sum_path) if File.exists? md5sum_path
    end

    ##
    # Get a (likely) URL to the tika instance
    def url
      "http://127.0.0.1:#{port}/"
    end

    protected

    def download
      unless File.exists?(download_path) && validate?(download_path)
        fetch_with_progressbar download_url, download_path
        validate! download_path
      end

      download_path
    end

    def validate?(file)
      Digest::MD5.file(file).hexdigest == expected_md5sum
    end

    def validate!(file)
      unless validate? file
        raise "MD5 mismatch" unless options[:ignore_md5sum]
      end
    end

    ##
    # Run the tika server
    def exec(options = {})
      args = ["java", "-jar", tika_binary] + tika_options.merge(options).map { |k, v| ["-#{k}", "#{v}"] }.flatten + [">&2"]
      io = IO.popen(env, args + [err: [:child, :out]])
      @pid = io.pid
    end

    private

    def download_url
      @download_url ||= options.fetch(:url, default_download_url)
    end

    def default_download_url
      @default_url ||= begin
        mirror_url = "http://www.apache.org/dyn/closer.cgi/tika/tika-server-#{version}.jar?asjson=true"
        json = open(mirror_url).read
        doc = JSON.parse(json)
        doc['preferred'] + doc['path_info']
      end
    end

    def md5url
      "http://archive.apache.org/dist/tika/tika-server-#{version}.jar.md5"
    end

    def version
      @version ||= options.fetch(:version, default_tika_version)
    end

    def tika_options
      options.fetch(:tika_options, {})
    end

    def env
      options.fetch(:env, {})
    end

    def default_tika_version
      TikaWrapper.default_tika_version
    end

    def download_path
      @download_path ||= options.fetch(:download_path, default_download_path)
    end

    def default_download_path
      File.join(Dir.tmpdir, File.basename(download_url))
    end

    def tika_dir
      @tika_dir ||= options.fetch(:instance_dir, File.join(Dir.tmpdir, File.basename(download_url, ".jar")))
    end

    def verbose?
      !!options.fetch(:verbose, false)
    end

    def managed?
      !!options.fetch(:managed, true)
    end

    def version_file
      options.fetch(:version_file, File.join(tika_dir, "VERSION"))
    end

    def expected_md5sum
      @md5sum ||= options.fetch(:md5sum, open(md5file).read.split(" ").first)
    end

    def tika_binary
      download_path
    end

    def md5sum_path
      File.join(Dir.tmpdir, File.basename(md5url))
    end

    def tmp_save_dir
      @tmp_save_dir ||= Dir.mktmpdir
    end

    def fetch_with_progressbar(url, output)
      pbar = ProgressBar.create(title: File.basename(url), total: nil, format: "%t: |%B| %p%% (%e )")
      open(url, content_length_proc: lambda do|t|
        if t && 0 < t
          pbar.total = t
        end
      end,
                progress_proc: lambda do|s|
                  pbar.progress = s
                end) do |io|
        IO.copy_stream(io, output)
      end
    end

    def md5file
      unless File.exists? md5sum_path
        fetch_with_progressbar md5url, md5sum_path
      end

      md5sum_path
    end
  end
end
