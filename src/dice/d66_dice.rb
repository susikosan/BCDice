module D66Dice
  def eval_d66_dice(string)
    if @d66Type == 0
      return nil
    end

    m = /^(S)?((\d+)?D66([NS])?)$/i.match(string)
    unless m
      return nil
    end

    @secret = !m[1].nil?
    command = m[2]
    times = m[3]&.to_i || 1
    suffix = m[4]

    swap_type = swap_type_by_suffix(suffix)

    dice_values = @randomizer.roll_d66(times, swap_type)
    return ": (#{command}) ＞ #{dice_values.join(',')}"
  end

  # @param [String]
  # @return [Symbol]
  def swap_type_by_suffix(suffix)
    if suffix == "S"
      :asc
    elsif suffix == "N"
      :none
    elsif @d66Type > 1
      :asc
    else
      :none
    end
  end
end
