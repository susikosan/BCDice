class Randomizer
  def initialize
    @rand_results = []
    @rand_values = []
  end

  attr_reader :rand_results, :rand_values

  def roll(times, sides)
    roll_barabara(times, sides).sum()
  end

  def roll_barabara(times, sides)
    Array.new(times) { rand(sides) }
  end

  # @param [Integer] times 振る回数
  # @param [Symbol] swap_type :asc 昇順, :desc 降順, :none 入れ替えなし
  # @return [Array<Integer>]
  def roll_d66(times, swap_type)
    Array.new(times) { roll_d66_once(swap_type) }
  end

  # @param [Symbol] swap_type :asc 昇順, :desc 降順, :none 入れ替えなし
  # @return [Integer]
  def roll_d66_once(swap_type)
    values = Array.new(2) { rand(6) }
    case swap_type
    when :asc
      values.sort!
    when :desc
      values.sort!.reverse!
    end

    return values.first * 10 + values.last
  end

  def rand(sides)
    ret = Kernel.rand(sides) + 1

    @rand_results.push([ret, sides])
    @rand_values.push(ret)
    return ret
  end
end

class StaticRands < Randomizer
  def initialize(rands)
    super()
    @rands = rands
  end

  def rand(sides)
    if @rands.nil? || @rands.empty?
      raise "nextRand is nil, so @rands is empty!! @rands:#{@rands.inspect}"
    end

    ret, expected_sides = @rands.shift
    if sides != expected_sides
      raise "invalid max value! [ #{ret} / #{sides} ] but NEED [ #{expected_sides} ] dice"
    end

    @rand_results.push([ret, sides])
    @rand_values.push(ret)

    return ret
  end
end
