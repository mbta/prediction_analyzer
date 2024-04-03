defmodule PredictionAnalyzer.Filters.StopGroups do
  @red_trunk ~w(70061 70063 70064 70065 70066 70067 70068 70069 70070 70071 70072 70073 70074 70075 70076 70077 70078 70079 70080 70081 70082 70083 70084)
  @ashmont_branch ~w(70085 70086 70087 70088 70089 70090 70091 70092 70093 70094)
  @braintree_branch ~w(70095 70096 70097 70098 70099 70100 70101 70102 70103 70104 70105)

  # GLX note: these do not include Science Park or Lechmere
  @green_trunk ~w(70150 70151 70152 70153 70154 70155 70156 70157 70158 70159 70196 70197 70198 70199 70200 70201 70202 70203 70204 70205 70206 71150 71151 71199)
  @b_branch ~w(70106 70107 70110 70111 70112 70113 70114 70115 70116 70117 70120 70121 70124 70125 70126 70127 70128 70129 70130 70131 70134 70135 70136 70137 70138 70139 70140 70141 70142 70143 70144 70145 70146 70147 70148 70149)
  @c_branch ~w(70211 70212 70213 70214 70215 70216 70217 70218 70219 70220 70223 70224 70225 70226 70227 70228 70229 70230 70231 70232 70233 70234 70235 70236 70237 70238)
  @d_branch ~w(70160 70161 70162 70163 70164 70165 70166 70167 70168 70169 70170 70171 70172 70173 70174 70175 70176 70177 70178 70179 70180 70181 70182 70183 70186 70187)
  @e_branch ~w(70239 70240 70241 70242 70243 70244 70245 70246 70247 70248 70249 70250 70251 70252 70253 70254 70255 70256 70257 70258 70260)
  @terminals ~w(70001 70036 70038 70059 70060 70061 70093 70094 70105 70106 70107 70160 70161 70196 70197 70198 70199 70201 70202 70205 70206 70237 70238 70260 70261 70275 70276 70838 71199, 70503)

  # Terminal departure platforms + away-from-terminal platforms up to 3 stops away. Note: 70001,
  # 70036, 70061, 70105, 70260, and 70261 include all platforms at the stop, since these terminals
  # do not have static arrival/departure platforms.
  @near_terminals_map %{
    blue: ~w(70038 70040 70042 70044 70053 70055 70057 70059),
    green_b: ~w(70106 70110 70112 70114),
    green_c: ~w(70232 70234 70236 70238),
    green_d: ~w(70160 70162 70164 70166),
    green_e: ~w(70260 70254 70256 70258),
    green_trunk: ~w(70155 70157 70159 70196 70197 70198 70199 70202 70204 70206),
    mattapan: ~w(70261 70263 70265 70267 70270 70272 70274 70276),
    orange: ~w(70001 70003 70005 70007 70032 70034 70036 70278),
    red_ashmont: ~w(70088 70090 70092 70094),
    red_braintree: ~w(70100 70102 70104 70105),
    red_trunk: ~w(70061 70063 70065 70067)
  }
  @near_terminals Map.values(@near_terminals_map) |> List.flatten()

  @groups [
    {"_trunk", "Trunk stops", @red_trunk ++ @green_trunk},
    {"_branch", "Branch stops",
     @ashmont_branch ++ @braintree_branch ++ @b_branch ++ @c_branch ++ @d_branch ++ @e_branch},
    {"_terminal", "Terminals", @terminals},
    {"_near_terminal", "Terminals + next 3 stops", @near_terminals},
    {"_ashmont_branch", "Red Line - Ashmont branch", @ashmont_branch},
    {"_braintree_branch", "Red Line - Braintree branch", @braintree_branch}
  ]

  @mappings Enum.map(@groups, fn {id, _name, stop_ids} -> {id, stop_ids} end) |> Enum.into(%{})

  @spec expand_groups([String.t()]) :: [String.t()]
  def expand_groups(stop_or_group_ids) do
    Enum.flat_map(stop_or_group_ids, fn id -> Map.get(@mappings, id, [id]) end)
  end

  @spec group_names() :: [{atom(), String.t()}]
  def group_names, do: Enum.map(@groups, fn {id, name, _stop_ids} -> {name, id} end)
end
