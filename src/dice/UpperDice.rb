# -*- coding: utf-8 -*-

require 'utils/ArithmeticEvaluator'
require 'utils/normalize'

module UpperDice
  include Normalize

  # 上方無限ロールを評価する
  #
  # @param [String] command
  # @return [String]
  # @return [nil] 上方無限ロールでない時にnilを返す
  def eval_upper_dice(command)
    command = command.upcase
    m = /(S)?\d+U\d+/i.match(command)
    unless m
      return nil
    end

    text = roll_add_dice(command)
    unless text
      return nil
    end

    @secret = !m[1].nil?
    return text
  end

  # 上方無限ロールを評価する
  #
  # @param [String] string
  # @return [String]
  # @return [nil] 上方無限ロールでない時にnilを返す
  def roll_add_dice(string)
    string = string.gsub(/-[sS]?[\d]+[uU][\d]+/, '') # 上方無限の引き算しようとしてる部分をカット

    m = /^S?(\d+U[\d\+\-U]+)(\[(\d+)\])?([-+\d]+)?(([<>=]+)(\d+))?(@(\d+))?/i.match(string)
    unless m
      return nil
    end

    expr = m[1]
    modifier_text = m[4]
    modifier = modifier_text.nil? ? 0 : ArithmeticEvaluator.new.eval(modifier_text)
    operator = normalize_operator(m[6])
    target = m[7]&.to_i
    reroll_threshold = getAddRollUpperTarget(m[3] || m[9])

    if reroll_threshold <= 1
      return ": (#{expr}[#{reroll_threshold}]#{modifier}) ＞ 無限ロールの条件がまちがっています"
    end

    dice_list = []
    expr.split("+").each do |dice|
      times, sides = dice.split("U", 2).map { |s| s.to_i }
      arr = roll_u(times, sides, reroll_threshold)
      if sortType & 2 != 0
        arr = arr.sort()
      end
      dice_list.concat(arr)
    end

    modifier_with_sign = formatBonus(modifier)
    command = "#{expr}[#{reroll_threshold}]#{modifier_text}"
    output = dice_list.map do |x|
      if x[1].length == 1
        x[0].to_s
      else
        "#{x[0]}[#{x[1].join(',')}]"
      end
    end.join(",") + modifier_with_sign

    values = dice_list.map { |x| x[0] }
    if operator
      modified_target = target - modifier
      success_count = dice_list.count { |x| x[0].send(operator, modified_target) }
      return ": (#{command}#{operator}#{target}) ＞ #{output} ＞ 成功数#{success_count}"
    else
      total = values.sum() + modifier
      max_value = values.max() + modifier
      return ": (#{command}) ＞ #{output} ＞ #{max_value}/#{total}(最大/合計)"
    end
  end

  def getAddRollUpperTarget(threshold)
    if upplerRollThreshold == "Max"
      2
    elsif threshold
      threshold.to_i
    else
      upplerRollThreshold
    end
  end

  # 入力の修正値の部分からボーナスの数値に変換する
  # @param [String] modifier 入力の修正値部分
  # @return [Integer] ボーナスの数値
  def getBonusValue(modifier)
    if modifier.empty?
      0
    else
      ArithmeticEvaluator.new.eval(modifier, fractionType.to_sym)
    end
  end

  # 出力用にボーナス値を整形する
  # @param [Integer] bonusValue ボーナス値
  # @return [String]
  def formatBonus(bonusValue)
    if bonusValue == 0
      ''
    elsif bonusValue > 0
      "+#{bonusValue}"
    else
      bonusValue.to_s
    end
  end

  # 上方無限ロールを振る
  #
  # @param [Integer] times 回数
  # @param [Integer] sides ダイスの面数
  # @param [Integer] threshold 振り足しの閾値
  # @result [Array<(Integer, Array<Integer>)>]
  def roll_u(times, sides, threshold)
    Array.new(times) do
      list = roll_u_once(sides, threshold)
      [list.sum(), list]
    end
  end

  # 1回上方無限ロールを行う。出目 >= thresholdの時に振り足す
  #
  # @param [Integer] sides
  # @param [Integer] threshold
  # @result [Array<Integer>]
  def roll_u_once(sides, threshold)
    ret = []
    loop do
      val = @randomizer.rand(sides)
      ret.push(val)
      unless val >= threshold
        break
      end
    end
    return ret
  end
end
