﻿package jp.kimulabo.flkinect {
	
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.IOErrorEvent;
	
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	public class FlKinect extends EventDispatcher {
		
		public static const RESOLUTION_X:uint = 640;
		public static const RESOLUTION_Y:uint = 480;
		public static const RGB_SIZE:int = RESOLUTION_X * RESOLUTION_Y * 4;
		public static const RECEIVE_DATA_SIZE:int = RGB_SIZE * 2 + 4 * 6;
		public static const SEND_DATA_SIZE:int = 6;
		public static const PORT:int = 8000;
		public static const HOST:String = "localhost";
		
		public static const SET_CAMERA_ENABLED:uint		= 0;
		public static const SET_DEPTH_ENABLED:uint		= 1;
		public static const SET_FAR_THRESHOLD:uint		= 2;
		public static const SET_NEAR_THRESHOLD:uint		= 3;
		public static const SET_TILT_DEGREE:uint		= 4;
		public static const SET_LED:uint				= 5;
		
		public static const LED_OFF:uint				= 0;
		public static const LED_GREEN:uint				= 1;
		public static const LED_RED:uint				= 2;
		public static const LED_YELLOW:uint				= 3;
		public static const LED_BLINK_YELLOW:uint		= 4;
		public static const LED_BLINK_GREEN:uint		= 5;
		public static const LED_BLINK_RED_YELLOW:uint	= 6;
		
		/*--------------------------------------------------
		* コンストラクタ
		--------------------------------------------------*/
		private var _socket:Socket;
		private var _connected:Boolean = false;
		private var _buffer:ByteArray;
		private var _cameraEnabled:Boolean = true;
		private var _depthEnabled:Boolean = true;
		private var _led:uint = 0;
		private var _tilt:int = 0;
		private var _farThreshold:Number = 0;
		private var _nearThreshold:Number = 1;
		private var _camera:BitmapData = new BitmapData( RESOLUTION_X, RESOLUTION_Y, false, 0 );
		private var _depth:BitmapData = new BitmapData( RESOLUTION_X, RESOLUTION_Y, false, 0 );
		
		/*--------------------------------------------------
		* Getter & Setter
		--------------------------------------------------*/
		public function get camera():BitmapData { return _camera; }
		public function get depth():BitmapData { return _depth; }
		
		public function get cameraEnabled():Boolean { return _cameraEnabled; }
		public function set cameraEnabled( i_value:Boolean ):void {
			_cameraEnabled = i_value;
			_sendData( SET_CAMERA_ENABLED, _cameraEnabled ? 1 : 0 );
			if ( !_cameraEnabled ) {
				var x:uint,y:uint;
				_camera.lock();
				for ( x=0; x<RESOLUTION_X; x++ ) for ( y=0; y<RESOLUTION_Y; y++ ) _camera.setPixel(x,y,0);
				_camera.unlock();
			}
		}
		
		public function get depthEnabled():Boolean { return _depthEnabled; }
		public function set depthEnabled( i_value:Boolean ):void {
			_depthEnabled = i_value;
			_sendData( SET_DEPTH_ENABLED, _depthEnabled ? 1 : 0 );
			if ( !_depthEnabled ) {
				var x:uint,y:uint;
				_depth.lock();
				for ( x=0; x<RESOLUTION_X; x++ ) for ( y=0; y<RESOLUTION_Y; y++ ) _depth.setPixel(x,y,0);
				_depth.unlock();
			}
		}
		
		public function get tilt():int { return _tilt; }
		public function set tilt( i_value:int ):void {
			_tilt = i_value;
			if ( _tilt > 30 ) _tilt = 30;
			else if ( _tilt < -30 ) _tilt = -30;
			_sendData( SET_TILT_DEGREE, _tilt );
		}
		
		public function get led():uint { return _led; }
		public function set led( i_value:uint ):void {
			_led = i_value;
			if ( _led > 6 ) _led = 6;
			_sendData( SET_LED, _led );
		}
		
		public function get farThreshold():Number { return _farThreshold; }
		public function set farThreshold( i_value:Number ):void {
			_farThreshold = i_value;
			_sendData( SET_FAR_THRESHOLD, _farThreshold );
		}
		
		public function get nearThreshold():Number { return _nearThreshold; }
		public function set nearThreshold( i_value:Number ):void {
			_nearThreshold = i_value;
			_sendData( SET_NEAR_THRESHOLD, _nearThreshold );
		}
		
		/*--------------------------------------------------
		* コンストラクタ
		--------------------------------------------------*/
		public function FlKinect() {
			_socket = new Socket();
			_buffer = new ByteArray();
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, _socketData);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, _socketError);
			_socket.addEventListener(Event.CONNECT, _socketConnect);
		}
		
		
		/*--------------------------------------------------
		* 接続
		--------------------------------------------------*/
		public function connect():void {
			_socket.connect(HOST,PORT);
		}
		
		/*--------------------------------------------------
		* ソケットイベント
		--------------------------------------------------*/
		private function _socketData( i_event:ProgressEvent ):void {
			if ( _socket.bytesAvailable < RECEIVE_DATA_SIZE ) return;
			//camera
			_buffer.position = 0;
			_socket.readBytes(_buffer, 0, RGB_SIZE);
			if ( _cameraEnabled ) {
				_buffer.endian = Endian.LITTLE_ENDIAN;
				_buffer.position = 0;
				_camera.lock();
				_camera.setPixels(_camera.rect,_buffer);
				_camera.unlock();
			}
			//depth
			_buffer.position = 0;
			_socket.readBytes(_buffer, 0, RGB_SIZE);
			if ( _depthEnabled ) {
				_buffer.endian = Endian.LITTLE_ENDIAN;
				_buffer.position = 0;
				_depth.lock();
				_depth.setPixels(_depth.rect,_buffer);
				_depth.unlock();
			}
			
			
			//data
			_buffer.position = 0;
			_socket.readBytes(_buffer, 0, 4 * 6);
			_buffer.endian = Endian.LITTLE_ENDIAN;
			var n:Number;
			n = _buffer.readFloat();
			_cameraEnabled = ( n > 0 ) as Boolean;
			n = _buffer.readFloat();
			_depthEnabled = ( n > 0 ) as Boolean;
			n = _buffer.readFloat();
			_farThreshold = n;
			n = _buffer.readFloat();
			_nearThreshold = n;
			n = _buffer.readFloat();
			_tilt = n;
			n = _buffer.readFloat();
			_led = n;
			
			dispatchEvent( new Event( Event.CHANGE ) );
		}
		
		private function _socketError( i_event:IOErrorEvent ):void {
			trace("flKinect socket error");
			_connected = false;
			dispatchEvent( i_event );
		}
		
		private function _socketConnect( i_event:Event ):void {
			trace("Connected to flKinect");
			_connected = true;
			dispatchEvent( new Event( Event.CONNECT ) );
		}
		
		private function _sendData( i_mode:int, i_value:Number ):void {
			if ( !_connected ) return;
			var d:ByteArray = new ByteArray();
			d.endian = Endian.LITTLE_ENDIAN;
			d.writeByte(i_mode);
			d.writeFloat( i_value );
			d.writeByte( 0x0a );
			_socket.writeBytes(d, 0, SEND_DATA_SIZE);
			_socket.flush();
		}
	}
}