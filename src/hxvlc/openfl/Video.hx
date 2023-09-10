package hxvlc.openfl;

#if (!cpp && !(desktop || android) && macro)
#error 'The current target platform isn\'t supported by hxvlc.'
#end
import haxe.io.Path;
import hxvlc.libvlc.LibVLC;
import hxvlc.libvlc.Types;
import hxvlc.openfl.Macros;
import lime.app.Event;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

/**
 * @author Mihai Alexandru (M.A. Jigsaw).
 *
 * This class lets you to use LibVLC externs as a bitmap that you can displaylist along other items.
 */
#if android
@:headerInclude('android/log.h')
#end
@:headerInclude('stdint.h')
@:headerInclude('stdio.h')
@:cppNamespaceCode('
static unsigned format_setup(void **data, char *chroma, unsigned *width, unsigned *height, unsigned *pitches, unsigned *lines)
{
	Video_obj *self = reinterpret_cast<Video_obj *>(*data);

	unsigned formatWidth = (*width);
	unsigned formatHeight = (*height);

	(*pitches) = formatWidth * 4;
	(*lines) = formatHeight;

	strcpy(chroma, "RV32");

	self->videoWidth = formatWidth;
	self->videoHeight = formatHeight;

	self->events[9] = true;

	if (self->pixels != NULL)
		delete self->pixels;

	self->pixels = new uint8_t[formatWidth * formatHeight * 4];
	return 1;
}

static void *lock(void *data, void **p_pixels)
{
	Video_obj *self = reinterpret_cast<Video_obj *>(data);
	*p_pixels = self->pixels;
	return NULL; // picture identifier, not needed here
}

static void callbacks(const libvlc_event_t *event, void *data)
{
	Video_obj *self = reinterpret_cast<Video_obj *>(data);

	switch (event->type)
	{
		case libvlc_MediaPlayerOpening:
			self->events[0] = true;
			break;
		case libvlc_MediaPlayerPlaying:
			self->events[1] = true;
			break;
		case libvlc_MediaPlayerStopped:
			self->events[2] = true;
			break;
		case libvlc_MediaPlayerPaused:
			self->events[3] = true;
			break;
		case libvlc_MediaPlayerEndReached:
			self->events[4] = true;
			break;
		case libvlc_MediaPlayerEncounteredError:
			self->events[5] = true;
			break;
		case libvlc_MediaPlayerForward:
			self->events[6] = true;
			break;
		case libvlc_MediaPlayerBackward:
			self->events[7] = true;
			break;
		case libvlc_MediaPlayerMediaChanged:
			self->events[8] = true;
			break;
	}
}

static void logging(void *data, int level, const libvlc_log_t *ctx, const char *fmt, va_list args)
{
	#ifdef __ANDROID__
	switch (level)
	{
		case LIBVLC_DEBUG:
			__android_log_vprint(ANDROID_LOG_DEBUG, "HXVLC", fmt, args);
			break;
		case LIBVLC_NOTICE:
			__android_log_vprint(ANDROID_LOG_INFO, "HXVLC", fmt, args);
			break;
		case LIBVLC_WARNING:
			__android_log_vprint(ANDROID_LOG_WARN, "HXVLC", fmt, args);
			break;
		case LIBVLC_ERROR:
			__android_log_vprint(ANDROID_LOG_ERROR, "HXVLC", fmt, args);
			break;
	}
	#else
	vprintf(fmt, args);
	#endif
}')
class Video extends Bitmap
{
	/**
	 * The width of the video, in pixels.
	 */
	public var videoWidth(default, null):Int = 0;

	/**
	 * The height of the video, in pixels.
	 */
	public var videoHeight(default, null):Int = 0;

	/**
	 * The video's time in milliseconds.
	 */
	public var time(get, set):Int;

	/**
	 * The video's position as percentage between `0.0` and `1.0`.
	 */
	public var position(get, set):Single;

	/**
	 * The video's length in milliseconds.
	 */
	public var length(get, never):Int;

	/**
	 * The video's duration.
	 */
	public var duration(get, never):Int;

	/**
	 * The video's media resource locator.
	 */
	public var mrl(get, never):String;

	/**
	 * The video's audio volume in percents (0 = mute, 100 = nominal / 0dB).
	 */
	public var volume(get, set):Int;

	/**
	 * The video's audio channel.
	 *
	 * - [Stereo] = 1
	 * - [RStereo] = 2
	 * - [Left] = 3
	 * - [Right] = 4
	 * - [Dolbys] = 5
	 */
	public var channel(get, set):Int;

	/**
	 * The video's audio delay in microseconds.
	 */
	public var delay(get, set):Int;

	/**
	 * The video's play rate.
	 */
	public var rate(get, set):Single;

	/**
	 * Whether the video is playing or not.
	 */
	public var isPlaying(get, never):Bool;

	/**
	 * Whether the video is seekable or not.
	 */
	public var isSeekable(get, never):Bool;

	/**
	 * Whether the video can be paused or not.
	 */
	public var canPause(get, never):Bool;

	/**
	 * The video's mute status.
	 */
	public var mute(get, set):Bool;

	public var onOpening(default, null):Event<Void->Void>;
	public var onPlaying(default, null):Event<Void->Void>;
	public var onStopped(default, null):Event<Void->Void>;
	public var onPaused(default, null):Event<Void->Void>;
	public var onEndReached(default, null):Event<Void->Void>;
	public var onEncounteredError(default, null):Event<Void->Void>;
	public var onForward(default, null):Event<Void->Void>;
	public var onBackward(default, null):Event<Void->Void>;
	public var onMediaChanged(default, null):Event<Void->Void>;
	public var onTextureSetup(default, null):Event<Void->Void>;

	@:noCompletion private var oldTime:Float = 0;
	@:noCompletion private var deltaTime:Float = 0;
	@:noCompletion private var events:Array<Bool> = [];
	@:noCompletion private var pixels:cpp.RawPointer<cpp.UInt8>;
	@:noCompletion private var instance:cpp.RawPointer<LibVLC_Instance_T>;
	@:noCompletion private var mediaPlayer:cpp.RawPointer<LibVLC_MediaPlayer_T>;
	@:noCompletion private var mediaItem:cpp.RawPointer<LibVLC_Media_T>;
	@:noCompletion private var eventManager:cpp.RawPointer<LibVLC_EventManager_T>;

	/**
	 * Initializes a Video object.
	 */
	public function new():Void
	{
		super(bitmapData, AUTO, true);

		for (i in 0...9)
			events[i] = false;

		onOpening = new Event<Void->Void>();
		onPlaying = new Event<Void->Void>();
		onStopped = new Event<Void->Void>();
		onPaused = new Event<Void->Void>();
		onEndReached = new Event<Void->Void>();
		onEncounteredError = new Event<Void->Void>();
		onForward = new Event<Void->Void>();
		onBackward = new Event<Void->Void>();
		onMediaChanged = new Event<Void->Void>();
		onTextureSetup = new Event<Void->Void>();

		#if android
		// libvlcjni doesn't set this on it's own so...
		Sys.putEnv('VLC_DATA_PATH', '/system/usr/share');
		#end

		#if mac
		// This needs to be set as MacOS libvlc can't set the plugins path automatically...
		Sys.putEnv('VLC_PLUGIN_PATH', Path.directory(Sys.programPath()) + '/plugins');
		#end

		#if (windows || mac)
		untyped __cpp__('const char *args[] = { "--ignore-config", "--intf=dummy", "--no-lua", "--reset-plugins-cache" };');
		#else
		untyped __cpp__('const char *args[] = { "--ignore-config", "--intf=dummy", "--no-lua" };');
		#end

		instance = LibVLC.create(untyped __cpp__('sizeof(args) / sizeof(*args)'), untyped __cpp__('args'));

		#if HXVLC_LOGGING
		LibVLC.log_set(instance, untyped __cpp__('logging'), untyped __cpp__('NULL'));
		#end
	}

	/**
	 * Call this function to play a video.
	 *
	 * @param location The local filesystem path or the media location url.
	 * @param shouldLoop Whether to repeat the video or not.
	 *
	 * @return `true` if the video started playing or `false` if there's an error.
	 */
	public function play(location:String, shouldLoop:Bool = false):Bool
	{
		if (location != null && location.indexOf('://') != -1)
			mediaItem = LibVLC.media_new_location(instance, location);
		else if (location != null)
		{
			#if windows
			mediaItem = LibVLC.media_new_path(instance, Path.normalize(location).split('/').join('\\'));
			#else
			mediaItem = LibVLC.media_new_path(instance, Path.normalize(location));
			#end
		}
		else
			return false;

		LibVLC.media_add_option(mediaItem, shouldLoop ? "input-repeat=65535" : "input-repeat=0");

		if (mediaPlayer != null)
			LibVLC.media_player_set_media(mediaPlayer, mediaItem);
		else
			mediaPlayer = LibVLC.media_player_new_from_media(mediaItem);

		LibVLC.media_release(mediaItem);

		LibVLC.video_set_format_callbacks(mediaPlayer, untyped __cpp__('format_setup'), untyped __cpp__('NULL'));
		LibVLC.video_set_callbacks(mediaPlayer, untyped __cpp__('lock'), untyped __cpp__('NULL'), untyped __cpp__('NULL'), untyped __cpp__('this'));

		attachEvents();

		return LibVLC.media_player_play(mediaPlayer) == 0;
	}

	/**
	 * Call this function to stop the video.
	 */
	public function stop():Void
	{
		if (mediaPlayer != null)
			LibVLC.media_player_stop(mediaPlayer);
	}

	/**
	 * Call this function to pause the video.
	 */
	public function pause():Void
	{
		if (mediaPlayer != null)
			LibVLC.media_player_set_pause(mediaPlayer, 1);
	}

	/**
	 * Call this function to resume the video.
	 */
	public function resume():Void
	{
		if (mediaPlayer != null)
			LibVLC.media_player_set_pause(mediaPlayer, 0);
	}

	/**
	 * Call this function to toggle the pause of the video.
	 */
	public function togglePaused():Void
	{
		if (mediaPlayer != null)
			LibVLC.media_player_pause(mediaPlayer);
	}

	/**
	 * Frees libvlc and the memory that is used to store the Video object.
	 */
	public function dispose():Void
	{
		detachEvents();

		if (mediaPlayer != null)
		{
			LibVLC.media_player_stop(mediaPlayer);
			LibVLC.media_player_release(mediaPlayer);
		}

		if (bitmapData != null)
		{
			bitmapData.dispose();
			bitmapData = null;
		}

		videoWidth = 0;
		videoHeight = 0;
		pixels = null;

		events.splice(0, events.length);

		if (instance != null)
		{
			#if HXVLC_LOGGING
			LibVLC.log_unset(instance);
			#end
			LibVLC.release(instance);
		}

		eventManager = null;
		mediaPlayer = null;
		mediaItem = null;
		instance = null;
	}

	// Get & Set Methods
	@:noCompletion private function get_time():Int
	{
		return mediaPlayer != null ? cast(LibVLC.media_player_get_time(mediaPlayer), Int) : -1;
	}

	@:noCompletion private function set_time(value:Int):Int
	{
		if (mediaPlayer != null)
			LibVLC.media_player_set_time(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_position():Single
	{
		return mediaPlayer != null ? LibVLC.media_player_get_position(mediaPlayer) : -1;
	}

	@:noCompletion private function set_position(value:Single):Single
	{
		if (mediaPlayer != null)
			LibVLC.media_player_set_position(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_length():Int
	{
		return mediaPlayer != null ? cast(LibVLC.media_player_get_length(mediaPlayer), Int) : -1;
	}

	@:noCompletion private function get_duration():Int
	{
		return mediaItem != null ? cast(LibVLC.media_get_duration(mediaItem), Int) : -1;
	}

	@:noCompletion private function get_mrl():String
	{
		return mediaItem != null ? cast(LibVLC.media_get_mrl(mediaItem), String) : null;
	}

	@:noCompletion private function get_volume():Int
	{
		return mediaPlayer != null ? LibVLC.audio_get_volume(mediaPlayer) : -1;
	}

	@:noCompletion private function set_volume(value:Int):Int
	{
		if (mediaPlayer != null)
			LibVLC.audio_set_volume(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_channel():Int
	{
		return mediaPlayer != null ? LibVLC.audio_get_channel(mediaPlayer) : -1;
	}

	@:noCompletion private function set_channel(value:Int):Int
	{
		if (mediaPlayer != null)
			LibVLC.audio_set_channel(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_delay():Int
	{
		return mediaPlayer != null ? cast(LibVLC.audio_get_delay(mediaPlayer), Int) : -1;
	}

	@:noCompletion private function set_delay(value:Int):Int
	{
		if (mediaPlayer != null)
			LibVLC.audio_set_delay(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_rate():Single
	{
		return mediaPlayer != null ? LibVLC.media_player_get_rate(mediaPlayer) : -1;
	}

	@:noCompletion private function set_rate(value:Single):Single
	{
		if (mediaPlayer != null)
			LibVLC.media_player_set_rate(mediaPlayer, value);

		return value;
	}

	@:noCompletion private function get_isPlaying():Bool
	{
		return mediaPlayer != null ? LibVLC.media_player_is_playing(mediaPlayer) : false;
	}

	@:noCompletion private function get_isSeekable():Bool
	{
		return mediaPlayer != null ? LibVLC.media_player_is_seekable(mediaPlayer) : false;
	}

	@:noCompletion private function get_canPause():Bool
	{
		return mediaPlayer != null ? LibVLC.media_player_can_pause(mediaPlayer) : false;
	}

	@:noCompletion private function get_mute():Bool
	{
		return mediaPlayer != null ? (LibVLC.audio_get_mute(mediaPlayer) > 0) : false;
	}

	@:noCompletion private function set_mute(value:Bool):Bool
	{
		if (mediaPlayer != null)
			LibVLC.audio_set_mute(mediaPlayer, value);

		return value;
	}

	// Overrides
	@:noCompletion private override function __enterFrame(elapsed:Int):Void
	{
		if (events.contains(true))
			checkEvents();

		if (__renderable && isPlaying)
		{
			deltaTime += elapsed;

			// 8.(3) means 120 fps in milliseconds...
			if (Math.abs(deltaTime - oldTime) >= 8.3)
				oldTime = deltaTime;
			else
				return;

			if (bitmapData != null && pixels != null)
			{
				bitmapData.lock();
				bitmapData.setPixels(bitmapData.rect, cpp.Pointer.fromRaw(pixels).toUnmanagedArray(videoWidth * videoHeight * 4));
				bitmapData.unlock();
			}

			__setRenderDirty();
		}
	}

	// Internal Methods
	@:noCompletion private function checkEvents():Void
	{
		Macros.checkEvent(events[0], {
			onOpening.dispatch();
		});

		Macros.checkEvent(events[1], {
			onPlaying.dispatch();
		});

		Macros.checkEvent(events[2], {
			onStopped.dispatch();
		});

		Macros.checkEvent(events[3], {
			onPaused.dispatch();
		});

		Macros.checkEvent(events[4], {
			onEndReached.dispatch();
		});

		Macros.checkEvent(events[5], {
			onEncounteredError.dispatch();
		});

		Macros.checkEvent(events[6], {
			onForward.dispatch();
		});

		Macros.checkEvent(events[7], {
			onBackward.dispatch();
		});

		Macros.checkEvent(events[8], {
			onMediaChanged.dispatch();
		});

		Macros.checkEvent(events[9], {
			if (bitmapData != null)
			{
				// Don't dispose the bitmapData if isn't necessary...
				if (bitmapData.width != videoWidth && bitmapData.height != videoHeight)
					bitmapData.dispose();
				else
					return;
			}
			
			bitmapData = new BitmapData(videoWidth, videoHeight, true, 0);

			smoothing = true;

			onTextureSetup.dispatch();
		});
	}

	@:noCompletion private function attachEvents():Void
	{
		if (mediaPlayer == null || eventManager != null)
			return;

		eventManager = LibVLC.media_player_event_manager(mediaPlayer);

		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerOpening, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerPlaying, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerStopped, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerPaused, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerEndReached, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerEncounteredError, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerForward, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerBackward, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_attach(eventManager, LibVLC_MediaPlayerMediaChanged, untyped __cpp__('callbacks'), untyped __cpp__('this'));
	}

	@:noCompletion private function detachEvents():Void
	{
		if (eventManager == null)
			return;

		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerOpening, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerPlaying, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerStopped, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerPaused, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerEndReached, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerEncounteredError, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerForward, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerBackward, untyped __cpp__('callbacks'), untyped __cpp__('this'));
		LibVLC.event_detach(eventManager, LibVLC_MediaPlayerMediaChanged, untyped __cpp__('callbacks'), untyped __cpp__('this'));
	}
}
