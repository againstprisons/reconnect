module ReConnect::Config
  Dir.glob(File.join(ReConnect.root, 'app', 'config', '*.rb')).each do |f|
    require f
  end

  module_function
  def parsers
    list = ReConnect::Config.constants.map do |cname|
      p = ReConnect::Config.const_get(cname)
      next unless p.respond_to?(:accept?)

      p
    end

    list.compact!
    list.sort!{|a, b| a.order <=> b.order}
    list
  end
end
