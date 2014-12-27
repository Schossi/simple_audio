/*
  Copyright (C) 2012 John McCutchan <john@johnmccutchan.com>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

part of simple_audio;

/** An [AudioSource] is analogous to a speaker in the game world.
 *
 * The only way to play an [AudioClip] is with an [AudioSource].
 *
 * An [AudioSource] can be [positional] or not. Positional [AudioSource]s
 * sound different depending on where the listener is. Non-positional
 * [AudioSource]s sound the same regarldess of where the listener is.
 * The location of the listener can be controlled with an [AudioManager].
 *
 *
 * *NOTE:* By default an [AudioSource] is [positional].
 */
class AudioSource {
	final _appliedEffect = <AudioEffect>[];
	AudioManager _manager;
	String _name;
	GainNode _output;
	GainNode _gainNode;
	PannerNode _panNode;
	List<AudioSound> _sounds;
	num _mutedVolume;
	bool _isPaused = false;
	num _x = 0.0;
	num _y = 0.0;
	num _z = 0.0;
	num minDistance = 0;
	bool _positional = true;

	String get name => _name;

	void _setupNodes() {
		_panNode.disconnect(0);
		_gainNode.disconnect(0);

		var effectInput = _gainNode;

		if (_positional) {
			// Positional, we need a pan node.
			_gainNode.connectNode(_panNode);
			effectInput = _panNode;
		}

		for (var i = 0; i < _appliedEffect.length; ++i) {
			final effect = _appliedEffect[i];

			effectInput = effect._apply(effectInput);
		}

		effectInput.connectNode(_output);
	}

	AudioSource._internal(this._manager, this._name, this._output) {
		_gainNode = _manager._context.createGain();
		_panNode = _manager._context.createPanner();
		_panNode.coneOuterGain = 1.0;
		_setupNodes();
		_sounds = new List<AudioSound>();
	}

	bool get positional => _positional;

	void set positional(bool b) {
		if (b != _positional) {
			_positional = b;
			_setupNodes();
		}
	}

	/** Get the volume of the source. 0.0 <= volume <= 1.0. */
	num get volume => _gainNode.gain.value;

	/** Set the volume for the source. All sounds being played are affected. */
	void set volume(num v) {
		_gainNode.gain.value = v;
	}

	Map toJson() {
		return {
			"_name": _name,
			"volume": _gainNode.gain.value,
			"_mutedVolume": _mutedVolume,
			"_isPaused": _isPaused,
			"_x": _x,
			"_y": _y,
			"_z": _z,
		};
	}

	AudioSource fromMap(Map map) {
		_gainNode.gain.value = map["volume"];
		_mutedVolume = map["_mutedVolume"];
		_isPaused = map["_isPaused"];
		_name = map["_name"];
		_x = map["_x"];
		_y = map["_y"];
		_z = map["_z"];
		setPosition(_x, _y, _z);
		return this;
	}

	/// Check if the source has at least one active sound.
	bool get isPlayingSound {
		_scanSounds();

		return _sounds.isNotEmpty;
	}

	/** Is the source muted? */
	bool get mute {
		return _mutedVolume != null;
	}

	/** Mute or unmute the source. */
	void set mute(bool b) {
		if (b) {
			if (_mutedVolume != null) {
				// Double mute.
				return;
			}
			_mutedVolume = volume;
			volume = 0.0;
		} else {
			if (_mutedVolume == null) {
				// Double unmute.
				return;
			}
			volume = _mutedVolume;
			_mutedVolume = null;
		}
	}

	/** Play [clip] from the source. */
	AudioSound playOnce(AudioClip clip) {
		return playOnceIn(0.0, clip);
	}

	/** Play [clip] from the source starting in [delay] seconds. */
	AudioSound playOnceIn(num delay, AudioClip clip) {
		AudioSound sound = new AudioSound._internal(this, clip, false);
		_sounds.add(sound);
		sound.play(delay);
		sound.pause = pause;

		return sound;
	}

	/** Play [clip] from the source in a loop. */
	AudioSound playLooped(AudioClip clip) {
		return playLoopedIn(0.0, clip);
	}

	/** Play [clip] from the source in a loop starting in [delay]
   * seconds.
   */
	AudioSound playLoopedIn(num delay, AudioClip clip) {
		AudioSound sound = new AudioSound._internal(this, clip, true);
		_sounds.add(sound);
		sound.play(delay);
		sound.pause = pause;
		return sound;
	}

	void _scanSounds() {
		for (int i = _sounds.length - 1; i >= 0; i--) {
			AudioSound sound = _sounds[i];
			if (sound.isFinished) {
				int last = _sounds.length - 1;
				// Copy last over
				_sounds[i] = _sounds[last];
				// Pop end
				_sounds.removeLast();
				sound.stop();
			}
		}
	}

	/** Apply [effect] to the audio source. Multiple effects are chained in the
   *  same order as they are added. */
	void applyEffect(AudioEffect effect) {
		_appliedEffect.add(effect);
		_setupNodes();
	}

	/** Clear all effects that are applied to the source. */
	void clearEffects() {
		_appliedEffect.clear();
		_setupNodes();
	}

	/** Is the source currently paused? */
	bool get pause => _isPaused;

	/** Pause or resume the source */
	void set pause(bool b) {
		if (b) {
			if (_isPaused == true) {
				// Double pause.
				return;
			}
			_pause();
			_isPaused = true;
		} else {
			if (_isPaused == false) {
				// Double unpause.
				return;
			}
			_resume();
			_isPaused = false;
		}
	}

	void _pause() {
		_scanSounds();
		_sounds.forEach((sound) {
			sound.pause = true;
		});
	}

	void _resume() {
		_scanSounds();
		_sounds.forEach((sound) {
			sound.pause = false;
		});
	}

	/** Stop the source. Affects all playing and scheduled sounds. */
	void stop() {
		_sounds.forEach((sound) {
			sound.stop();
		});
		_scanSounds();
	}

	/** X position of the source. */
	num get x => _x;
	/** Y position of the source. */
	num get y => _y;
	/** Z position of the source. */
	num get z => _z;

	/**
   * Set the position of the source.
   */
	void setPosition(num x, num y, num z) {
		_x = x;
		_y = y;
		_z = z;

		if (this.minDistance > 0) {
			_adjustPositionToMinimum(this.minDistance);
		} else if (AudioManager.minDistance > 0) {
			_adjustPositionToMinimum(AudioManager.minDistance);
		}

		_panNode.setPosition(_x * AudioManager.positionalScale, _y * AudioManager.positionalScale, _z * AudioManager.positionalScale);
	}

	void _adjustPositionToMinimum(num _distance) {
		//name vector components so i dont get confused
		num p1 = _x;
		num p2 = _y;
		num p3 = _z;

		num q1 = _manager.x;
		num q2 = _manager.y;
		num q3 = _manager.z;

		//if there is no problem, dont solve it
		num currentDistance = _getDistance(p1, p2, p3, q1, q2, q3);
		if (currentDistance >= _distance) return;

		//get vector from listener to source
		num sub1 = p1 - q1;
		num sub2 = p2 - q2;
		num sub3 = p3 - q3;

		//normalize it
		sub1 /= currentDistance;
		sub2 /= currentDistance;
		sub3 /= currentDistance;

		//scale it to mindistance
		sub1 *= _distance;
		sub2 *= _distance;
		sub3 *= _distance;

		//set values
		_x = q1 + sub1;
		_y = q2 + sub2;
		_z = q3 + sub3;
		
		//verify
		num newDistance = _getDistance(_x, _y, _z, q1, q2, q3);		
	}

	num _getDistance(p1, p2, p3, q1, q2, q3) {
		num sum = 0;
		sum += math.pow((p1 - q1), 2);
		sum += math.pow((p2 - q2), 2);
		sum += math.pow((p3 - q3), 2);
		return math.sqrt(sum);
	}

	/**
   * Set the linear velocity of the source.
   */
	void setVelocity(num x, num y, num z) {
		_panNode.setVelocity(x * AudioManager.positionalScale, y * AudioManager.positionalScale, z * AudioManager.positionalScale);
	}
}
