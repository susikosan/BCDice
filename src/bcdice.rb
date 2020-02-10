module BCDice
  # IDを指定してシステムを取得する
  # @param [String] id
  # @return [Class]
  def self.get_system_by_id(id)
    loader = DiceBotLoaderList.find(id)
    return loader&.loadDiceBot&.class || DiceBotLoader.loadUnknownGame(id)&.class
  end
end
