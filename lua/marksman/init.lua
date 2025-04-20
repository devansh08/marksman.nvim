local M = {}

---@type MarksmanOpts|{}
local global_opts = {}

---@type table<GotoCmd, string>
local goto_cmd_map = {
  ["edit"] = "e",
  ["drop"] = "drop",
  ["tab-drop"] = "tab drop",
}

--- Marks Map
--- Key: Mark index
--- Value: Buffer ID, File name, Line number, Column number
---@type table<integer, (string|integer)[]>
local marks = {}
---@type integer
local top = 0

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
    if top == i then
      pref = "> "
    end

    print(string.format(pref .. format_string, row[1], row[2], row[3]))
  end
end

---@param mark (string|integer)[]
local function gotoBuf(mark)
  vim.cmd(goto_cmd_map[global_opts.goto_cmd] .. " " .. tostring(mark[2]))
  vim.api.nvim_win_set_cursor(0, { tonumber(mark[3]) or 1, mark[4] - 1 or 0 })
end

local function addMark()
  ---@type integer
  local id = vim.api.nvim_get_current_buf()
  ---@type string, integer, integer
  local filename, row, col = vim.api.nvim_buf_get_name(id), vim.fn.line("."), vim.fn.col(".")

  -- Check the previous entry in marks stack is different
  ---@type (string|integer)[]
  local mark = marks[top]
  if mark == nil or not (mark[1] == id and mark[2] == filename and mark[3] == row and mark[4] == col) then
    top = top + 1
    marks[top] = { id, filename, row, col }
  end
end

---@param args vim.api.keyset.create_user_command.command_args
local function removeMark(args)
  ---@type integer
  local index = tonumber(args.fargs[1]) or 1
  marks[index] = { marks[index][1], "", -1, -1 }
end

local function listMarks()
  if #marks == 0 then
    print("[Marksman] Marks stack is empty")
    return
  end

  ---@type string[][]
  local output = {}

  ---@type string
  local cwd_pattern = vim.uv.cwd():gsub("([%.%+%-%*%?%[%]%^%$%(%)%|])", "%%%1")
  for index, val in ipairs(marks) do
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
local function gotoMark(args)
  ---@type integer|nil
  local index = tonumber(args.fargs[1])
  if index and index <= #marks then
    top = index
    gotoBuf(marks[index])
  end
end

local function prevMark()
  if top > 1 then
    gotoBuf(marks[top])
    top = top - 1
  else
    print("[Marksman] Already at the top of Marksman stack")
  end
end

local function nextMark()
  if top < #marks then
    top = top + 1
    gotoBuf(marks[top])
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
  global_opts = {
    goto_cmd = opts.goto_cmd or "drop",
  }

  vim.api.nvim_create_user_command("MarksmanAdd", addMark, {})
  vim.api.nvim_create_user_command("MarksmanRemove", removeMark, {
    nargs = 1,
  })
  vim.api.nvim_create_user_command("MarksmanList", listMarks, {})
  vim.api.nvim_create_user_command("MarksmanGoto", gotoMark, {
    nargs = 1,
  })
  vim.api.nvim_create_user_command("MarksmanPrev", prevMark, {})
  vim.api.nvim_create_user_command("MarksmanNext", nextMark, {})
end

return M
