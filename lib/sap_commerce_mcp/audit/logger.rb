# frozen_string_literal: true

require 'json'
require 'logger'

module SapCommerceMcp
  module Audit
    class Logger
      attr_reader :log_path

      def initialize(project_path)
        SapCommerceMcp.ensure_data_dir!
        @project_path = project_path
        @log_path = File.join(SapCommerceMcp.data_dir, 'logs')
        @mutex = Mutex.new
      end

      def log_request(tool_name, input, output, duration_ms, error: nil)
        entry = {
          timestamp: Time.now.utc.iso8601(3),
          request_id: generate_request_id,
          tool: tool_name,
          input: sanitize_input(input),
          output: {
            success: error.nil?,
            result_count: if output.is_a?(Array)
                            output.size
                          else
                            output.is_a?(Hash) ? output.keys.size : nil
                          end,
            processing_time_ms: duration_ms.round(2)
          },
          project_path: @project_path,
          error: error&.message
        }

        write_log_entry(entry)
        entry
      end

      def log_indexing(stats)
        entry = {
          timestamp: Time.now.utc.iso8601(3),
          event: 'indexing_complete',
          stats: stats,
          project_path: @project_path
        }

        write_log_entry(entry)
        entry
      end

      def log_error(context, error)
        entry = {
          timestamp: Time.now.utc.iso8601(3),
          event: 'error',
          context: context,
          error: {
            message: error.message,
            class: error.class.name,
            backtrace: error.backtrace&.first(5)
          },
          project_path: @project_path
        }

        write_log_entry(entry)
        entry
      end

      def read_recent_logs(limit = 50)
        today_log = log_file_path
        return [] unless File.exist?(today_log)

        # Read last N lines from today's log
        lines = File.readlines(today_log).last(limit)
        lines.map { |line| JSON.parse(line.strip) rescue nil }.compact
      end

      def cleanup_old_logs(days = 30)
        cutoff_date = Date.today - days
        deleted_count = 0

        Dir.glob(File.join(@log_path, 'audit-*.log')).each do |log_file|
          if (match = File.basename(log_file).match(/audit-(\d{4}-\d{2}-\d{2})\.log/))
            log_date = Date.parse(match[1])
            if log_date < cutoff_date
              File.delete(log_file)
              deleted_count += 1
            end
          end
        end

        deleted_count
      end

      private

      def write_log_entry(entry)
        @mutex.synchronize do
          File.open(log_file_path, 'a') do |f|
            f.puts(JSON.generate(entry))
          end
        end
      rescue => e
        warn "Failed to write audit log: #{e.message}"
      end

      def log_file_path
        date_str = Date.today.strftime('%Y-%m-%d')
        File.join(@log_path, "audit-#{date_str}.log")
      end

      def generate_request_id
        "#{Time.now.to_i}-#{rand(10000)}"
      end

      def sanitize_input(input)
        # Remove sensitive data if any
        case input
        when Hash
          input.transform_values { |v| sanitize_input(v) }
        when String
          input.length > 1000 ? "#{input[0..1000]}... (truncated)" : input
        else
          input
        end
      end
    end
  end
end
