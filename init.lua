module(..., package.seeall)

local Image = require 'bamboo.models.image'
local gd = require 'gd'

local urlprefix = 'rapidupload'
local pathprefix = '../plugins/rapidupload/views/'

local TMPLS = {
	['basic'] = pathprefix + 'rapidupload.html',
	['logoupload'] = pathprefix + 'imgupload.html',	
	['imgupload'] = pathprefix + 'imgupload.html',	
}




--[[
{^ rapidupload     ^}


--]]
local _args_collector = {}


function main(args, env)
	assert(args._tag, '[Error] @plugin rapidupload - missing _tag.')
	_args_collector[args._tag] = args
	
	args.tmpl = args.tmpl or 'basic'
	assert(args.tmpl, '[Error] @plugin rapidupload - invalid param tmpl.')
	
	args.name = args.name or 'image_id'
	args.thumbnail_name = args.thumbnail_name or 'thumbnail_id'
	
	if args.tmpl == 'logoupload' then
		args.thumbnail_width = args.thumbnail_width or 100
		args.thumbnail_height = args.thumbnail_height or 100
	elseif args.tmpl == 'imgupload' then
		args.thumbnail_width = args.thumbnail_width or 300
		args.thumbnail_height = args.thumbnail_height or 300		
	end	
	
	return View(TMPLS[args.tmpl])(args)

end

function guessPhotoFormat(path)
	local im_src
	local name, ext = path:match('(.+)%.(%w+)$')
	ext = ext:lower()
	if ext == 'jpg' or ext == 'jpeg' then 
		im_src = gd.createFromJpeg(path)
	elseif ext == 'png' then
		im_src = gd.createFromPng(path)
	elseif ext == 'gif' then
		im_src = gd.createFromGif(path)
	end
	return im_src
end


function imgupload(web, req)
	local params = req.PARAMS
	assert(params._tag, '[Error] @plugin rapidupload function imgupload - missing _tag.')
	ptable(params)
	local _args = _args_collector[params._tag]

	local newimg, result_type = Image:process(web, req, dir)
	if not newimg then 
		return false
	end
	
	--计算图片像素
	local im_src = guessPhotoFormat(newimg.path)
	local width, height = im_src:sizeXY()
	newimg.width = width
	newimg.height = height
	newimg:save()
	
	
	local thumbnail_width
	local thumbnail_height
	local tmpl = _args.tmpl
	if tmpl == 'logoupload' then
		-- scale to specified width and height
		thumbnail_width = _args.thumbnail_width
		thumbnail_height = _args.thumbnail_height
	elseif tmpl == 'imgupload' then
		thumbnail_width = _args.thumbnail_width
		thumbnail_height = math.floor(thumbnail_width * height / width)
	end
	local thumbnail_img = gd.createTrueColor(thumbnail_width, thumbnail_height)
	thumbnail_img:copyResampled(im_src, 0, 0, 0, 0, thumbnail_width, thumbnail_height, width, height)
	
	
	local thumbnail_path = newimg.path
	local main, ext = thumbnail_path:match('^(.+)(%.%w+)$')
	main = main + '_thumbnail'
	thumbnail_path = main + '.gif'
	thumbnail_img:gif(thumbnail_path)
	
	local thumbnail_name = newimg.name
	local main, ext = thumbnail_name:match('^(.+)(%.%w+)$')
	main = main + '_thumbnail'
	thumbnail_name = main + '.gif'
	
	local thumbnail = Image {
		name = thumbnail_name,
		path = thumbnail_path,
		width = thumbnail_width,
		height = thumbnail_height
	}
	thumbnail:save()
	
	if req.ajax then
		return web:json { 
			['success'] = true,
			[_args.name] = newimg.id,
			[_args.thumbnail_name] = thumbnail.id,
			['thumbnail_path'] = '/' .. thumbnail_path,
			['thumbnail_width'] = thumbnail_width,
			['thumbnail_height'] = thumbnail_height,			
		}
	else
		return web:page(([[{"success": true, "%s": "%s", "%s": "%s", "thumbnail_path": "%s", "thumbnail_width": "%s", "thumbnail_height": "%s"}]]):format(
		_args.name, newimg.id, _args.thumbnail_name, thumbnail.id, thumbnail_path, thumbnail_width, thumbnail_height))
	end
	

end


URLS = {
	['/rapidupload/imgupload/'] = imgupload,  -- put register view customized in handler_entry.lua
	--['/' + urlprefix + '/postcomment/'] = postComment,

}

