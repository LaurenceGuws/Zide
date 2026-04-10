local repo_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local android_root = repo_root .. "/android/bootstrap-bridge"
local sdk_root = vim.fn.expand("~/.local/share/zide-android-sdk")

if vim.fn.isdirectory(sdk_root) == 1 then
  vim.env.ANDROID_HOME = sdk_root
  vim.env.ANDROID_SDK_ROOT = sdk_root
end

vim.g.zide_android_sdk_root = sdk_root
vim.g.zide_android_host_root = android_root
vim.g.zide_dev_references_root = repo_root .. "/dev_references"

vim.api.nvim_create_user_command("ZideAndroidHostCd", function()
  vim.cmd.lcd(vim.fn.fnameescape(android_root))
  vim.notify("local cwd -> " .. android_root, vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("ZideAndroidEnv", function()
  vim.notify(
    "ANDROID_HOME=" .. (vim.env.ANDROID_HOME or "") .. "\n" ..
    "ANDROID_SDK_ROOT=" .. (vim.env.ANDROID_SDK_ROOT or "") .. "\n" ..
    "android_root=" .. android_root,
    vim.log.levels.INFO
  )
end, {})
