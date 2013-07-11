module Bombay
  module Bench
    NO_COLOR="\x1b[0m"
    OK_COLOR="\x1b[32;01m"
    ERROR_COLOR="\x1b[31;01m"
    WARN_COLOR="\x1b[33;01m"

    def profile
      return unless block_given?
      start = Time.now
      yield
      puts "#{OK_COLOR}===> SUMMARY#{NO_COLOR}"
      puts "Time: #{(Time.now - start)}"
    end
  end
end
