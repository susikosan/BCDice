# -*- coding: utf-8 -*-

require "dice/choice"
require "dice/calc"
require "dice/barabara_dice"
require "dice/AddDice"
require "dice/RerollDice"
require "dice/UpperDice"
require "dice/d66_dice"
require "utils/normalize"

class DiceBot
  # 空の接頭辞（反応するコマンド）
  EMPTY_PREFIXES_PATTERN = /(^|\s)(S)?()(\s|$)/i.freeze

  # 接頭辞（反応するコマンド）の配列を返す
  # @return [Array<String>]
  class << self
    attr_reader :prefixes
  end

  # 接頭辞（反応するコマンド）の正規表現を返す
  # @return [Regexp]
  class << self
    attr_reader :prefixesPattern
  end

  include Choice
  include Calc
  include AddDice
  include BarabaraDice
  include RerollDice
  include UpperDice
  include D66Dice
  include Normalize

  # 接頭辞（反応するコマンド）を設定する
  # @param [Array<String>] prefixes 接頭辞のパターンの配列
  # @return [self]
  def self.setPrefixes(prefixes)
    @prefixes = prefixes.
                # 最適化が効くように内容の文字列を変更不可にする
                map(&:freeze).
                # 配列全体を変更不可にする
                freeze
    @prefixesPattern = /(^|\s)(S)?(#{prefixes.join('|')})(\s|$)/i.freeze

    self
  end

  # 接頭辞（反応するコマンド）をクリアする
  # @return [self]
  def self.clearPrefixes
    @prefixes = [].freeze
    @prefixesPattern = EMPTY_PREFIXES_PATTERN

    self
  end

  # 継承された際にダイスボットの接頭辞リストをクリアする
  # @param [DiceBot] subclass DiceBotを継承したクラス
  # @return [void]
  def self.inherited(subclass)
    subclass.clearPrefixes
  end

  clearPrefixes

  attr_writer :randomizer

  def initialize(randomizer: Randomizer.new)
    @sortType = 0 # ソート設定(1 = 足し算ダイスでソート有, 2 = バラバラロール（Bコマンド）でソート有, 3 = １と２両方ソート有）
    @sameDiceRerollCount = 0 # ゾロ目で振り足し(0=無し, 1=全部同じ目, 2=ダイスのうち2個以上同じ目)
    @sameDiceRerollType = 0 # ゾロ目で振り足しのロール種別(0=判定のみ, 1=ダメージのみ, 2=両方)
    @d66Type = 1 # d66の差し替え(0=D66無し, 1=順番そのまま([5,3]->53), 2=昇順入れ替え([5,3]->35)
    @upplerRollThreshold = 0 # 上方無限
    @rerollNumber = 0 # 振り足しする条件
    @defaultSuccessTarget = "" # 目標値が空欄の時の目標値
    @rerollLimitCount = 10000 # 振り足し回数上限
    @fractionType = "omit" # 端数の処理 ("omit"=切り捨て, "roundUp"=切り上げ, "roundOff"=四捨五入)

    @gameType = 'DiceBot'

    @randomizer = randomizer
    @secret = false

    if !prefixs.empty? && self.class.prefixes.empty?
      # 従来の方法（#prefixs）で接頭辞を設定していた場合でも
      # クラス側に接頭辞が設定されるようにする
      warn("#{gameType}: #prefixs is deprecated. Please use .setPrefixes.")
      self.class.setPrefixes(prefixs)
    end
  end

  attr_accessor :rerollLimitCount

  attr_reader :sameDiceRerollCount, :sameDiceRerollType, :d66Type
  attr_reader :upplerRollThreshold
  attr_reader :defaultSuccessTarget, :rerollNumber, :fractionType

  # @param [String] text
  # @return [String]
  # @return [nil]
  def eval(text)
    @full_text = text
    @original_command = @full_text.split(' ', 2).first
    @preprocessed_command = parren_killer(@original_command)
    command = @preprocessed_command.upcase

    input = isGetOriginalMessage ? @preprocessed_command : command

    ret = dice_command(input) ||
          eval_choice(command) ||
          eval_calc(command) ||
          eval_add_dice(command) ||
          eval_barabara_dice(command) ||
          eval_reroll_dice(command) ||
          eval_upper_dice(command) ||
          eval_d66_dice(command)
    return ret
  end

  def info
    {
      'name' => gameName,
      'gameType' => gameType,
      'prefixs' => self.class.prefixes,
      'info' => getHelpMessage,
    }
  end

  def gameName
    gameType
  end

  def secret?
    @secret
  end

  # 接頭辞（反応するコマンド）の配列を返す
  # @return [Array<String>]
  def prefixes
    self.class.prefixes
  end

  # @deprecated 代わりに {#prefixes} を使ってください
  alias prefixs prefixes

  attr_reader :gameType

  attr_writer :upplerRollThreshold

  # @param [Integer] max
  # @return [Integer] 0以上max未満の整数
  def rand(max)
    @randomizer.roll(1, max) - 1
  end

  def roll(dice_cnt, dice_max, dice_sort = 0, dice_add = 0)
    dice_cnt = dice_cnt.to_i
    dice_max = dice_max.to_i

    total = 0
    dice_str = ""
    numberSpot1 = 0
    cnt_max = 0
    n_max = 0
    d9_on = false
    dice_result = []

    # dice_add = 0 if( ! dice_add )

    if (d66Type != 0) && (dice_max == 66)
      dice_sort = 0
      dice_cnt = 2
      dice_max = 6
    end

    if isD9 && (dice_max == 9)
      d9_on = true
      dice_max += 1
    end

    unless (dice_cnt <= $DICE_MAXCNT) && (dice_max <= $DICE_MAXNUM)
      return total, dice_str, numberSpot1, cnt_max, n_max
    end

    dice_cnt.times do |i|
      i += 1
      dice_now = 0
      dice_n = 0
      dice_st_n = ""
      round = 0

      loop do
        dice_n = @randomizer.rand(dice_max)
        dice_n -= 1 if d9_on

        dice_now += dice_n

        dice_st_n += "," unless dice_st_n.empty?
        dice_st_n += dice_n.to_s
        round += 1

        break unless (dice_add > 1) && (dice_n >= dice_add)
      end

      total += dice_now

      if round >= 2
        dice_result.push("#{dice_now}[#{dice_st_n}]")
      else
        dice_result.push(dice_now)
      end

      numberSpot1 += 1 if dice_now == 1
      cnt_max += 1 if  dice_now == dice_max
      n_max = dice_now if dice_now > n_max
    end

    if dice_sort != 0
      dice_str = dice_result.sort_by { |a| a.to_s.sub(/\[[\d,]+\]/, '').to_i }.join(",")
    else
      dice_str = dice_result.join(",")
    end

    return total, dice_str, numberSpot1, cnt_max, n_max
  end

  attr_reader :sortType

  def getHelpMessage
    ''
  end

  ####################         テキスト前処理        ########################
  def parren_killer(string)
    debug("parren_killer input", string)

    round_type = fractionType.to_sym
    string = string.gsub(%r{\([\d/\+\*\-\(\)]+\)}) do |expr|
      ArithmeticEvaluator.new.eval(expr, round_type)
    end

    debug("diceBot.changeText(string) begin", string)
    string = changeText(string)
    debug("diceBot.changeText(string) end", string)

    string = string.gsub(/([\d]+[dD])([^\w]|$)/) { "#{Regexp.last_match(1)}6#{Regexp.last_match(2)}" }

    debug("parren_killer output", string)

    return string
  end

  def changeText(string)
    debug("DiceBot.parren_killer_add called")
    string
  end

  def dice_command(string)
    m = self.class.prefixesPattern.match(string)
    unless m
      return nil
    end

    secret = !m[2].nil?
    command = m[3]

    output_msg, secret_flg = rollDiceCommand(command)
    if output_msg.nil? || output_msg.empty? || output_msg == '1'
      return nil
    end

    secret_flg ||= false
    @secret = secret || secret_flg

    return ": #{output_msg}"
  end

  # 通常ダイスボットのコマンド文字列は全て大文字に強制されるが、
  # これを嫌う場合にはこのメソッドを true を返すようにオーバーライドすること。
  def isGetOriginalMessage
    false
  end

  # 各システムがこのメソッドをオーバーライドする
  def rollDiceCommand(_command)
    nil
  end

  def setDiffText(diffText)
    @diffText = diffText
  end

  # valueとtargetをoperatorで比較する
  # @param [Integer] value
  # @param [String] operator
  # @param [Integer] target
  # @return [Integer] 比較の結果がtrueなら1、偽なら0を返す
  def compare(value, operator, target)
    operator = normalize_operator(operator)
    if operator.nil?
      return 0
    end

    return value.send(operator, target) ? 1 : 0
  end

  def dice_command_xRn(_string, _nick_e)
    ''
  end

  def check_2D6(_total_n, _dice_n, _signOfInequality, _diff, _dice_cnt, _dice_max, _n1, _n_max) # ゲーム別成功度判定(2D6)
    ''
  end

  def check_nD6(_total_n, _dice_n, _signOfInequality, _diff, _dice_cnt, _dice_max, _n1, _n_max) # ゲーム別成功度判定(nD6)
    ''
  end

  def check_nD10(_total_n, _dice_n, _signOfInequality, _diff, _dice_cnt, _dice_max, _n1, _n_max) # ゲーム別成功度判定(nD10)
    ''
  end

  def check_1D100(_total_n, _dice_n, _signOfInequality, _diff, _dice_cnt, _dice_max, _n1, _n_max)    # ゲーム別成功度判定(1d100)
    ''
  end

  def check_1D20(_total_n, _dice_n, _signOfInequality, _diff, _dice_cnt, _dice_max, _n1, _n_max)     # ゲーム別成功度判定(1d20)
    ''
  end

  def get_table_by_2d6(table)
    get_table_by_nD6(table, 2)
  end

  def get_table_by_1d6(table)
    get_table_by_nD6(table, 1)
  end

  def get_table_by_nD6(table, count)
    get_table_by_nDx(table, count, 6)
  end

  def get_table_by_nDx(table, count, diceType)
    num, = roll(count, diceType)

    text = getTableValue(table[num - count])

    return '1', 0 if text.nil?

    return text, num
  end

  def get_table_by_1d3(table)
    debug("get_table_by_1d3")

    count = 1
    num, = roll(count, 6)
    debug("num", num)

    index = ((num - 1) / 2)
    debug("index", index)

    text = table[index]

    return '1', 0 if text.nil?

    return text, num
  end

  # D66 ロール用（スワップ、たとえば出目が【６，４】なら「６４」ではなく「４６」とする
  def get_table_by_d66_swap(table)
    isSwap = true
    number = getD66(isSwap)
    return get_table_by_number(number, table), number
  end

  # D66 ロール用
  def get_table_by_d66(table)
    dice1, = roll(1, 6)
    dice2, = roll(1, 6)

    num = (dice1 - 1) * 6 + (dice2 - 1)

    text = table[num]

    indexText = "#{dice1}#{dice2}"

    return '1', indexText if text.nil?

    return text, indexText
  end

  # ダイスロールによるポイント等の取得処理用（T&T悪意、ナイトメアハンター・ディープ宿命、特命転校生エクストラパワーポイントなど）
  def getDiceRolledAdditionalText(_n1, _n_max, _dice_max)
    ''
  end

  # ダイス目による補正処理（現状ナイトメアハンターディープ専用）
  def getDiceRevision(_n_max, _dice_max, _total_n)
    return '', 0
  end

  # ダイス目文字列からダイス値を変更する場合の処理（現状クトゥルフ・テック専用）
  def changeDiceValueByDiceText(dice_now, _dice_str, _isCheckSuccess, _dice_max)
    dice_now
  end

  # SW専用
  def setRatingTable(_nick_e, _tnick, _channel_to_list)
    '1'
  end

  # ガンドッグのnD9専用
  def isD9
    false
  end

  # シャドウラン4版用グリッチ判定
  def getGrichText(_numberSpot1, _dice_cnt_total, _suc)
    ''
  end

  # SW2.0 の超成功用
  def check2dCritical(critical, dice_new, dice_arry, loop_count); end

  def is2dCritical
    false
  end

  # 振り足しを行うべきかを返す
  # @param [Integer] loop_count ループ数
  # @return [Boolean]
  def should_reroll?(loop_count)
    loop_count < @rerollLimitCount || @rerollLimitCount == 0
  end

  # ** 汎用表サブルーチン
  def get_table_by_number(index, table, default = '1')
    table.each do |item|
      number = item[0]
      if number >= index
        return getTableValue(item[1])
      end
    end

    return getTableValue(default)
  end

  def getTableValue(data)
    if data.is_a?(Proc)
      return data.call()
    end

    return data
  end

  def analyzeDiceCommandResultMethod(command)
    # get～DiceCommandResultという名前のメソッドを集めて実行、
    # 結果がnil以外の場合それを返して終了。
    methodList = public_methods(false).select do |method|
      /^get.+DiceCommandResult$/ === method.to_s
    end

    methodList.each do |method|
      result = send(method, command)
      return result unless result.nil?
    end

    return nil
  end

  def get_table_by_nDx_extratable(table, count, diceType)
    number, diceText = roll(count, diceType)
    text = getTableValue(table[number - count])
    return text, number, diceText
  end

  def getTableCommandResult(command, tables, isPrintDiceText = true)
    info = tables[command]
    return nil if info.nil?

    name = info[:name]
    type = info[:type].upcase
    table = info[:table]

    if (type == 'D66') && (@d66Type == 2)
      type = 'D66S'
    end

    text, number, diceText =
      case type
      when /(\d+)D(\d+)/
        count = Regexp.last_match(1).to_i
        diceType = Regexp.last_match(2).to_i
        limit = diceType * count - (count - 1)
        table = getTableInfoFromExtraTableText(table, limit)
        get_table_by_nDx_extratable(table, count, diceType)
      when 'D66', 'D66N'
        table = getTableInfoFromExtraTableText(table, 36)
        item, value = get_table_by_d66(table)
        value = value.to_i
        output = item[1]
        diceText = (value / 10).to_s + "," + (value % 10).to_s
        [output, value, diceText]
      when 'D66S'
        table = getTableInfoFromExtraTableText(table, 21)
        output, value = get_table_by_d66_swap(table)
        value = value.to_i
        diceText = (value / 10).to_s + "," + (value % 10).to_s
        [output, value, diceText]
      else
        raise "invalid dice Type #{command}"
      end

    text = text.gsub("\\n", "\n")
    text = rollTableMessageDiceText(text)

    return nil if text.nil?

    return "#{name}(#{number}[#{diceText}]) ＞ #{text}" if isPrintDiceText && !diceText.nil?

    return "#{name}(#{number}) ＞ #{text}"
  end

  def rollTableMessageDiceText(text)
    message = text.gsub(/(\d+)D(\d+)/) do
      m = $~
      diceCount = m[1]
      diceMax = m[2]
      value, = roll(diceCount, diceMax)
      "#{diceCount}D#{diceMax}(=>#{value})"
    end

    return message
  end

  def getTableInfoFromExtraTableText(text, count = nil)
    if text.is_a?(String)
      text = text.split(/\n/)
    end

    newTable = text.map do |item|
      if item.is_a?(String) && (/^(\d+):(.*)/ === item)
        [Regexp.last_match(1).to_i, Regexp.last_match(2)]
      else
        item
      end
    end

    unless count.nil?
      if newTable.size != count
        raise "invalid table size:#{newTable.size}\n#{newTable.inspect}"
      end
    end

    return newTable
  end

  def roll_tables(command, tables)
    table = tables[command]
    unless table
      return nil
    end

    return table.roll(@randomizer)
  end
end
