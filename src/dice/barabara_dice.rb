require "utils/normalize"

module BarabaraDice
  include Normalize

  # @param [String] command
  # @return [String | nil]
  def eval_barabara_dice(command)
    string = command
    suc = 0
    signOfInequality = ""
    diff = 0
    output = ""

    string = string.gsub(/-[\d]+B[\d]+/, '') # バラバラダイスを引き算しようとしているのを除去

    unless /^(S)?(([\d]+B[\d]+(\+[\d]+B[\d]+)*)(([<>=]+)([\d]+))?)$/ =~ string
      return nil
    end

    @secret = !Regexp.last_match(1).nil?

    string = Regexp.last_match(2)
    if Regexp.last_match(5)
      diff = Regexp.last_match(7).to_i
      string = Regexp.last_match(3)
      signOfInequality = marshalSignOfInequality(Regexp.last_match(6))
    elsif  /([<>=]+)(\d+)/ =~ defaultSuccessTarget
      diff = Regexp.last_match(2).to_i
      signOfInequality = marshalSignOfInequality(Regexp.last_match(1))
    end

    dice_a = string.split(/\+/)
    dice_cnt_total = 0
    numberSpot1 = 0

    dice_a.each do |dice_o|
      dice_cnt, dice_max, = dice_o.split(/[bB]/)
      dice_cnt = dice_cnt.to_i
      dice_max = dice_max.to_i

      dice_dat = roll(dice_cnt, dice_max, (sortType & 2), 0, signOfInequality, diff)
      suc += dice_dat[5]
      output += "," if output != ""
      output += dice_dat[1]
      numberSpot1 += dice_dat[2]
      dice_cnt_total += dice_cnt
    end

    if signOfInequality != ""
      string += "#{signOfInequality}#{diff}"
      output = "#{output} ＞ 成功数#{suc}"
      output += getGrichText(numberSpot1, dice_cnt_total, suc)
    end
    output = ": (#{string}) ＞ #{output}"

    return output
  end
end
