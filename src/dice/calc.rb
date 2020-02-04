module Calc
  # @return [String]
  # @return [nil]
  def eval_calc(command)
    m = /^C([-\d]+)/.match(command)
    unless m
      return nil
    end

    return ": 計算結果 ＞ #{m[1]}"
  end
end
