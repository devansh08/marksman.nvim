local M = {}

--- Marks Map
--- Key: Mark index
--- Value: [ Buffer ID, Line number, Column number ]
---@type table<integer, integer[]>
M.marks = {}
---@type integer
M.index = 0

--- Value: Buffer ID, Filename + Row/Col, Content
---@param output string[][]
local function pretty_print(output)
  ---@type integer[]
  local padding = {}
  for _, row in ipairs(output) do
    for i, val in ipairs(row) do
      padding[i] = math.max(padding[i] or 0, #val)
    end
  end

  local format_string = "%" .. padding[1] .. "s -> %-" .. padding[2] .. "s -> %s"
  for i, row in ipairs(output) do
    ---@type string
    local pref = "  "
    if M.index == i then
      pref = "> "
    end

    print(string.format(pref .. format_string, row[1], row[2], row[3]))
  end
end

function M.addMark()
  M.index = M.index + 1
  M.marks[M.index] = { vim.api.nvim_get_current_buf(), vim.fn.line("."), vim.fn.col(".") }
end

---@param args vim.api.keyset.create_user_command.command_args
function M.removeMark(args)
  ---@type integer
  local index = tonumber(args.fargs[1]) or 1
  M.marks[index] = { M.marks[index][1], -1, -1 }
end

function M.listMarks()
  ---@type string[][]
  local output = {}

  ---@type string
  local cwd_pattern = vim.uv.cwd():gsub("([%.%+%-%*%?%[%]%^%$%(%)%|])", "%%%1")
  for k, v in ipairs(M.marks) do
    if v[2] == -1 and v[3] == -1 then
      table.insert(output, { tostring(k), "", "" })
    else
      ---@type string
      local filename = vim.api.nvim_buf_get_name(v[1]):gsub(cwd_pattern .. "/", "")
      table.insert(output, {
        tostring(k),
        filename .. ":" .. v[2] .. ":" .. v[3],
        vim.api.nvim_buf_get_lines(v[1], v[2] - 1, v[2], false)[1],
      })
    end
  end

  if #output > 0 then
    pretty_print(output)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("MarksmanAdd", M.addMark, {})
  vim.api.nvim_create_user_command("MarksmanRemove", M.removeMark, {
    nargs = 1,
  })
  vim.api.nvim_create_user_command("MarksmanList", M.listMarks, {})
end

return M
