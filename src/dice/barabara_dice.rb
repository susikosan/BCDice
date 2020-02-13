require "utils/normalize"

module BarabaraDice
  include Normalize

  # @param [String] command
  # @return [String | nil]
  def eval_barabara_dice(command)
    m = /^(S)?((\d+B\d+(\+\d+B\d+)*)([<>=]+\d+)?)$/.match(command)
    unless m
      return nil
    end

    @secret = !m[1].nil?
    lhs = m[3]
    operator, target = parse_operator_and_target(m[5] || @defaultSuccessTarget)

    values = []
    lhs.split("+").each do |dice_literal|
      times, sides = dice_literal.split("B", 2).map(&:to_i)
      values += @randomizer.roll_barabara(times, sides)
    end

    if @sortType >= 2
      values.sort!
    end

    output = values.join(",")

    if operator
      num_successes = values.count { |val| val.send(operator, target) }
      output = "#{output} ＞ 成功数#{num_successes}"
      output += getGrichText(values.count(1), values.length, num_successes)
    end

    return ": (#{lhs}#{operator_to_s(operator)}#{target}) ＞ #{output}"
  end

  # @param [String | nil] str
  # @return [Array<(Integer, Integer)> || Array<(nil, nil)>]
  def parse_operator_and_target(str)
    m = /^([<>=]+)(\d+)/.match(str)
    unless m
      return nil, nil
    end

    operator = normalize_operator(m[1])
    target = m[2].to_i
    return operator, target
  end
end
