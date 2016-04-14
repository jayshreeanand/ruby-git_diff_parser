require 'delegate'
module GitDiffParser
  # The array of patch
  class Patches < DelegateClass(Array)
    # @return [Patches<Patch>]
    def self.[](*ary)
      new(ary)
    end

    # @param contents [String] `git diff` result
    #
    # @return [Patches<Patch>] parsed object
    def self.parse(contents)
      body = false
      file_names = ''
      file_name = ''
      patch = []
      lines = contents.lines
      line_count = lines.count
      parsed = new
      lines.each_with_index do |line, count|
        case line.chomp
        when /^diff(?<file_names>.*)/
          file_names = Regexp.last_match[:file_names]
          unless patch.empty?
            parsed << Patch.new(patch.join("\n") + "\n", file: file_name)
            patch.clear
            file_name = ''
          end
          body = false
        when /^Binary files/
          if line.chomp.match(%r{Binary files .* b/(?<file_name>.*) differ})
            file_name = Regexp.last_match[:file_name]
          elsif line.match(%r{Binary files .*a/(?<file_name>.*) and})
            file_name = Regexp.last_match[:file_name]
          end
          body = true
          parsed << Patch.new('', file: file_name)
          file_name = ''
        when /^GIT binary patch/
          if file_names.match(%r{--git .* b/(?<file_name>.*)})
            file_name = Regexp.last_match[:file_name]
          elsif file_names.match(%r{--git a/(?<file_name>.* )})
            file_name = Regexp.last_match[:file_name]
          end
          body = true
          parsed << Patch.new('', file: file_name)
          file_name = ''
        when %r{^\-\-\- a/(?<file_name>.*)}
          file_name = Regexp.last_match[:file_name]
          body = true
        when %r{^\+\+\+ b/(?<file_name>.*)}
          file_name = Regexp.last_match[:file_name]
          body = true
        when /^(?<body>[\ @\+\-\\].*)/
          patch << Regexp.last_match[:body] if body
          if !patch.empty? && body && line_count == count + 1
            parsed << Patch.new(patch.join("\n") + "\n", file: file_name)
            patch.clear
            file_name = ''
          end
        end
      end
      parsed
    end

    # @return [Patches<Patch>]
    def initialize(*args)
      super Array.new(*args)
    end

    # @return [Array<String>] file path
    def files
      map(&:file)
    end

    # @return [Array<String>] target sha1 hash
    def secure_hashes
      map(&:secure_hash)
    end

    # @param file [String] file path
    #
    # @return [Patch, nil]
    def find_patch_by_file(file)
      find { |patch| patch.file == file }
    end

    # @param secure_hash [String] target sha1 hash
    #
    # @return [Patch, nil]
    def find_patch_by_secure_hash(secure_hash)
      find { |patch| patch.secure_hash == secure_hash }
    end
  end
end
