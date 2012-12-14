module Bombay
  class ServerVariables
    def initialize(hash={})
      @hash = hash ? hash.dup : {}
    end

    def []=(k,v)
      @hash[k] = v
    end

    def to_hash
      @hash
    end

    def to_s
      output = []
      @hash.sort.each { |k, v| output << "#{k}=\"#{v}\"" }
      output.join(' ')
    end

    def merge!(hash)
      hash ||= {}
      @hash.merge!(hash.to_hash)
    end

    def ==(obj)
      @hash == obj.to_hash
    end
  end
end
