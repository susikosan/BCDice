#!/bin/ruby -Ku
# -*- coding: utf-8 -*-

require 'log'
require 'configBcDice.rb'
require 'utils/ArithmeticEvaluator.rb'
require 'utils/normalize'

#============================== 起動法 ==============================
# 上記設定をしてダブルクリック、
# もしくはコマンドラインで
#
# ruby bcdice.rb
#
# とタイプして起動します。
#
# このとき起動オプションを指定することで、ソースを書き換えずに設定を変更出来ます。
#
# -s サーバ設定      「-s(サーバ):(ポート番号)」     (ex. -sirc.trpg.net:6667)
# -c チャンネル設定  「-c(チャンネル名)」            (ex. -c#CoCtest)
# -n Nick設定        「-n(Nick)」                    (ex. -nDicebot)
# -g ゲーム設定      「-g(ゲーム指定文字列)」        (ex. -gCthulhu)
# -m メッセージ設定  「-m(Notice_flgの番号)」        (ex. -m0)
# -e エクストラカード「-e(カードセットのファイル名)」(ex. -eTORG_SET.txt)
# -i IRC文字コード   「-i(文字コード名称)」          (ex. -iISO-2022-JP)
#
# ex. ruby bcdice.rb -sirc.trpg.net:6667 -c#CoCtest -gCthulhu
#
# プレイ環境ごとにバッチファイルを作っておくと便利です。
#
# 終了時はボットにTalkで「お疲れ様」と発言します。($quitCommandで変更出来ます。)
#====================================================================

require 'diceBot/DiceBot'
require 'diceBot/DiceBotLoader'
require 'diceBot/DiceBotLoaderList'
require 'dice/AddDice'
require 'dice/UpperDice'
require 'dice/RerollDice'
require 'dice/choice'
require 'utils/randomizer'

class BCDiceCore
  VERSION = "3.0.0-alpha".freeze

  include Normalize

  def initialize(game_type: "DiceBot", rands: nil, test_mode: false)
    @isTest = test_mode
    @randomizer = rands ? StaticRands.new(rands) : Randomizer.new

    setGameByTitle(game_type)
  end

  # @param [String] str
  # @param [String] 結果。評価できなかった場合には空文字を返す
  def eval(str)
    head = str.split(' ', 2).first
    @messageOriginal = parren_killer(head)
    @message = @messageOriginal.upcase

    output = @diceBot.eval(@message)
    if output.nil?
      return ""
    end

    if @isTest && @diceBot.secret?
      output += "###secret dice###"
    end

    return output
  end

  def getGameType
    @diceBot.gameType
  end

  def setDiceBot(diceBot)
    return if  diceBot.nil?

    @diceBot = diceBot
    @diceBot.bcdice = self
    diceBot.randomizer = @randomizer
  end

  def getOriginalMessage
    @messageOriginal
  end

  #=========================================================================
  # **                           ランダマイザ
  #=========================================================================
  # ダイスロール
  def roll(dice_cnt, dice_max, dice_sort = 0, dice_add = 0, dice_ul = '', dice_diff = 0, dice_re = nil)
    dice_cnt = dice_cnt.to_i
    dice_max = dice_max.to_i
    dice_re = dice_re.to_i

    total = 0
    dice_str = ""
    numberSpot1 = 0
    cnt_max = 0
    n_max = 0
    cnt_suc = 0
    d9_on = false
    rerollCount = 0
    dice_result = []

    # dice_add = 0 if( ! dice_add )

    if (@diceBot.d66Type != 0) && (dice_max == 66)
      dice_sort = 0
      dice_cnt = 2
      dice_max = 6
    end

    if @diceBot.isD9 && (dice_max == 9)
      d9_on = true
      dice_max += 1
    end

    unless (dice_cnt <= $DICE_MAXCNT) && (dice_max <= $DICE_MAXNUM)
      return total, dice_str, numberSpot1, cnt_max, n_max, cnt_suc, rerollCount
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

      if dice_ul != ''
        suc = @diceBot.check_hit(dice_now, dice_ul, dice_diff)
        cnt_suc += suc
      end

      if dice_re
        rerollCount += 1 if dice_now >= dice_re
      end

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
      dice_str = dice_result.sort_by { |a| dice_num(a) }.join(",")
    else
      dice_str = dice_result.join(",")
    end

    return total, dice_str, numberSpot1, cnt_max, n_max, cnt_suc, rerollCount
  end

  def getRandResults
    @randomizer.rand_results
  end

  def dice_num(dice_str)
    dice_str = dice_str.to_s
    return dice_str.sub(/\[[\d,]+\]/, '').to_i
  end

  ####################         テキスト前処理        ########################
  def parren_killer(string)
    debug("parren_killer input", string)

    string = changeRangeTextToNumberText(string)

    round_type = @diceBot.fractionType.to_sym
    string = string.gsub(%r{\([\d/\+\*\-\(\)]+\)}) do |expr|
      ArithmeticEvaluator.new.eval(expr, round_type)
    end

    debug("diceBot.changeText(string) begin", string)
    string = @diceBot.changeText(string)
    debug("diceBot.changeText(string) end", string)

    string = string.gsub(/([\d]+[dD])([^\w]|$)/) { "#{Regexp.last_match(1)}6#{Regexp.last_match(2)}" }

    debug("parren_killer output", string)

    return string
  end

  # [1...4]D[2...7] -> 2D7 のように[n...m]をランダムな数値へ変換
  def changeRangeTextToNumberText(string)
    debug('[st...ed] before string', string)

    while /^(.*?)\[(\d+)[.]{3}(\d+)\](.*)/ =~ string
      beforeText = Regexp.last_match(1)
      beforeText ||= ""

      rangeBegin = Regexp.last_match(2).to_i
      rangeEnd = Regexp.last_match(3).to_i

      afterText = Regexp.last_match(4)
      afterText ||= ""

      next unless rangeBegin < rangeEnd

      range = (rangeEnd - rangeBegin + 1)
      debug('range', range)

      rolledNumber, = roll(1, range)
      resultNumber = rangeBegin - 1 + rolledNumber
      string = "#{beforeText}#{resultNumber}#{afterText}"
    end

    debug('[st...ed] after string', string)

    return string
  end

  # 指定したタイトルのゲームを設定する
  # @param [String] gameTitle ゲームタイトル
  # @return [String] ゲームを設定したことを示すメッセージ
  def setGameByTitle(gameTitle)
    debug('setGameByTitle gameTitle', gameTitle)

    loader = DiceBotLoaderList.find(gameTitle)
    diceBot =
      if loader
        loader.loadDiceBot
      else
        DiceBotLoader.loadUnknownGame(gameTitle) || DiceBot.new
      end

    setDiceBot(diceBot)
    diceBot.postSet

    message = "Game設定を#{diceBot.gameName}に設定しました"
    debug('setGameByTitle message', message)

    return message
  end
end
