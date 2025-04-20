local M = {}

---@type MarksmanOpts|{}
M.opts = {}

---@type table<GotoCmd, string>
M.goto_cmd_map = {
  ["edit"] = "e",
  ["drop"] = "drop",
  ["tab-drop"] = "tab drop",
}

--- Marks Map
--- Key: Mark index
--- Value: Buffer ID, File name, Line number, Column number
---@type table<integer, (string|integer)[]>
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

---@param mark (string|integer)[]
local function gotoBuf(mark)
  vim.cmd(M.goto_cmd_map[M.opts.goto_cmd] .. " " .. tostring(mark[2]))
  vim.api.nvim_win_set_cursor(0, { tonumber(mark[3]) or 1, mark[4] - 1 or 0 })
end

function M.addMark()
  M.index = M.index + 1
  ---@type integer
  local id = vim.api.nvim_get_current_buf()
  M.marks[M.index] = { id, vim.api.nvim_buf_get_name(id), vim.fn.line("."), vim.fn.col(".") }
end

---@param args vim.api.keyset.create_user_command.command_args
function M.removeMark(args)
  ---@type integer
  local index = tonumber(args.fargs[1]) or 1
  M.marks[index] = { M.marks[index][1], "", -1, -1 }
end

function M.listMarks()
  ---@type string[][]
  local output = {}

  ---@type string
  local cwd_pattern = vim.uv.cwd():gsub("([%.%+%-%*%?%[%]%^%$%(%)%|])", "%%%1")
  for index, val in ipairs(M.marks) do
    ---@type integer, string, integer, integer
    local bufnr, name, row, col =
      tonumber(val[1]) or -1, tostring(val[2]), tonumber(val[3]) or -1, tonumber(val[4]) or -1
    if name == "" and row == -1 and col == -1 then
      table.insert(output, { tostring(index), "", "" })
    else
      ---@type string
      local filename = name:gsub(cwd_pattern .. "/", "")
      table.insert(output, {
        tostring(index),
        filename .. ":" .. row .. ":" .. col,
        vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]:match("^%s*(.-)%s*$"),
      })
    end
  end

  if #output > 0 then
    pretty_print(output)
  end
end

---@param args vim.api.keyset.create_user_command.command_args
function M.gotoMark(args)
  ---@type integer|nil
  local index = tonumber(args.fargs[1])
  if index and index <= #M.marks then
    M.index = index
    gotoBuf(M.marks[index])
  end
end

function M.prevMark()
  if M.index > 1 then
    M.index = M.index - 1
    gotoBuf(M.marks[M.index])
  else
    print("[Marksman] Already at the top of Marksman stack")
  end
end

function M.nextMark()
  if M.index < #M.marks then
    M.index = M.index + 1
    gotoBuf(M.marks[M.index])
  else
    print("[Marksman] Already at the bottom of Marksman stack")
  end
end

---@alias GotoCmd "edit"|"drop"|"tab-drop"

---@class MarksmanOpts
--- Define the command to open the file [default = "drop"]
--- - `edit`: will open the file in the current buffer (`:help :edit`)
--- - `drop`: will switch to an existing buffer which has the file already open;
---         else it will open the file in the current buffer (`:help :drop`)
--- - `tab-drop`: will switch to an existing tab page which has the file already open;
---             else it will open the file in the current tab-page (`:help :drop`)
---@field goto_cmd GotoCmd

---@param opts MarksmanOpts
function M.setup(opts)
  M.opts = {
    goto_cmd = opts.goto_cmd or "drop",
  }

  vim.api.nvim_create_user_command("MarksmanAdd", M.addMark, {})
  vim.api.nvim_create_user_command("MarksmanRemove", M.removeMark, {
    nargs = 1,
  })
  vim.api.nvim_create_user_command("MarksmanList", M.listMarks, {})
  vim.api.nvim_create_user_command("MarksmanGoto", M.gotoMark, {
    nargs = 1,
  })
  vim.api.nvim_create_user_command("MarksmanPrev", M.prevMark, {})
  vim.api.nvim_create_user_command("MarksmanNext", M.nextMark, {})
end

return M
