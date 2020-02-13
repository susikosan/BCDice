module D66Dice
  def eval_d66_dice(string)
    if @d66Type == 0
      return nil
    end

    unless /^S?D66/i.match(string)
      return nil
    end

    debug("match D66 roll")
    output, secret = d66dice(string)

    @secret = secret
    return output
  end

  def d66dice(string)
    string = string.upcase
    secret = false
    output = '1'

    string, secret, count, swapMarker = getD66Infos(string)
    return output, secret if string.nil?

    debug('d66dice count', count)

    d66List = []
    count.times do |_i|
      d66List << getD66ValueByMarker(swapMarker)
    end
    d66Text = d66List.join(',')
    debug('d66Text', d66Text)

    output = ": (#{string}) ＞ #{d66Text}"

    return output, secret
  end

  def getD66Infos(string)
    debug("getD66Infos, string", string)

    m = /(^|\s)(S)?((\d+)?D66(N|S)?)(\s|$)/i.match(string)
    unless m
      return nil
    end

    secret = !m[2].nil?
    string = m[3]
    count = (m[4] || 1).to_i
    swapMarker = (m[5] || "").upcase

    return string, secret, count, swapMarker
  end

  def getD66ValueByMarker(swapMarker)
    case swapMarker
    when "S"
      isSwap = true
      rollD66(isSwap)
    when "N"
      isSwap = false
      rollD66(isSwap)
    else
      getD66Value()
    end
  end

  def getD66Value(mode = nil)
    mode ||= @d66Type

    isSwap = (mode > 1)
    rollD66(isSwap)
  end

  def rollD66(isSwap)
    output = 0

    dice_a = @randomizer.rand(6)
    dice_b = @randomizer.rand(6)
    debug("dice_a", dice_a)
    debug("dice_b", dice_b)

    if isSwap && (dice_a > dice_b)
      # 大小でスワップするタイプ
      output = dice_a + dice_b * 10
    else
      # 出目そのまま
      output = dice_a * 10 + dice_b
    end

    debug("output", output)

    return output
  end
end
