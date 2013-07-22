part of LeapMotionDart;

/**
 * The Controller class is your main interface to the Leap Motion Controller.
 *
 * <p>Create an instance of this Controller class to access frames of tracking
 * data and configuration information. Frame data can be polled at any time using
 * the <code>Controller::frame()</code> function. Call <code>frame()</code> or <code>frame(0)</code>
 * to get the most recent frame. Set the history parameter to a positive integer
 * to access previous frames. A controller stores up to 60 frames in its frame history.</p>
 *
 * <p>Polling is an appropriate strategy for applications which already have an
 * intrinsic update loop, such as a game. You can also implement the Leap::Listener
 * interface to handle events as they occur. The Leap Motion dispatches events to the listener
 * upon initialization and exiting, on connection changes, and when a new frame
 * of tracking data is available. When these events occur, the controller object
 * invokes the appropriate callback function defined in the Listener interface.</p>
 *
 * <p>To access frames of tracking data as they become available:</p>
 *
 * <ul>
 * <li>Implement the Listener interface and override the <code>Listener::onFrame()</code> function.</li>
 * <li>In your <code>Listener::onFrame()</code> function, call the <code>Controller::frame()</code> function to access the newest frame of tracking data.</li>
 * <li>To start receiving frames, create a Controller object and add event listeners to the <code>Controller::addEventListener()</code> function.</li>
 * </ul>
 *
 * <p>When an instance of a Controller object has been initialized,
 * it calls the <code>Listener::onInit()</code> function when the listener is ready for use.
 * When a connection is established between the controller and the Leap,
 * the controller calls the <code>Listener::onConnect()</code> function. At this point,
 * your application will start receiving frames of data. The controller calls
 * the <code>Listener::onFrame()</code> function each time a new frame is available.
 * If the controller loses its connection with the Leap Motion software or
 * device for any reason, it calls the <code>Listener::onDisconnect()</code> function.
 * If the listener is removed from the controller or the controller is destroyed,
 * it calls the <code>Listener::onExit()</code> function. At that point, unless the listener
 * is added to another controller again, it will no longer receive frames of tracking data.</p>
 *
 * @author logotype
 *
 */
class Controller extends EventDispatcher
{
  /**
   * @private
   * The Listener subclass instance.
   */
  Listener _listener;

  /**
   * Socket connection.
   */
  WebSocket connection;

  /**
   * @private
   * Reports whether this Controller is connected to the Leap Motion Controller.
   */
  bool _isConnected = false;

  /**
   * The default policy.
   *
   * <p>Currently, the only supported policy is the background frames policy,
   * which determines whether your application receives frames of tracking
   * data when it is not the focused, foreground application.</p>
   */
  static const int POLICY_DEFAULT = 0;

  /**
   * Receive background frames.
   *
   * <p>Currently, the only supported policy is the background frames policy,
   * which determines whether your application receives frames of tracking
   * data when it is not the focused, foreground application.</p>
   */
  static const int POLICY_BACKGROUND_FRAMES = ( 1 << 0 );

  /**
   * Most recent received Frame.
   */
  Frame _latestFrame;

  /**
   * @private
   * History of frame of tracking data from the Leap Motion.
   */
  List<Frame> frameHistory = new List<Frame>();

  /**
   * @private
   * Required to suppress OS controls.
   */
  Timer _heartBeatTimer;

  /**
   * Constructs a Controller object.
   * @param host IP or hostname of the computer running the Leap Motion software.
   * (currently only supported for socket connections).
   *
   */
  Controller( { String host: null } )
  {
    _listener = new DefaultListener();

    if( !host )
    {
      connection = new WebSocket("ws://localhost:6437/v3.json");
    }
    else
    {
      connection = new WebSocket("ws://" + host + ":6437/v3.json");
    }

    _listener.onInit( this );
    
    connection.onOpen.listen( ( MessageEvent event ) {
      _isConnected = true;
      _listener.onConnect( this );
      _heartBeatTimer = new Timer.periodic( new Duration( milliseconds: 100 ), ( timer ) {
        connection.sendString( "{ \"heartbeat\": true }" );
      });
    });

    connection.onClose.listen( ( CloseEvent event ) {
      _isConnected = false;
      _listener.onDisconnect( this );
      _heartBeatTimer.cancel();
    });

    connection.onMessage.listen( ( MessageEvent event ) {
      int i;
      Map json;
      Frame currentFrame;
      Hand hand;
      Pointable pointable;
      Gesture gesture;
      bool isTool;
      int length;
      int type;

      json = JSON.parse( event.data );

      currentFrame = new Frame();
      currentFrame.controller = this;

      // Hands
      if ( json["hands"] != null )
      {
        i = 0;
        length = json["hands"].length;
        for ( i = 0; i < length; i++ )
        {
          hand = new Hand();
          hand.frame = currentFrame;
          hand.direction = new Vector3( json["hands"][ i ].direction[ 0 ], json["hands"][ i ].direction[ 1 ], json["hands"][ i ].direction[ 2 ] );
          hand.id = json["hands"][ i ].id;
          hand.palmNormal = new Vector3( json["hands"][ i ].palmNormal[ 0 ], json["hands"][ i ].palmNormal[ 1 ], json["hands"][ i ].palmNormal[ 2 ] );
          hand.palmPosition = new Vector3( json["hands"][ i ].palmPosition[ 0 ], json["hands"][ i ].palmPosition[ 1 ], json["hands"][ i ].palmPosition[ 2 ] );
          hand.stabilizedPalmPosition = new Vector3( json["hands"][ i ].stabilizedPalmPosition[ 0 ], json["hands"][ i ].stabilizedPalmPosition[ 1 ], json["hands"][ i ].stabilizedPalmPosition[ 2 ] );
          hand.palmVelocity = new Vector3( json["hands"][ i ].palmPosition[ 0 ], json["hands"][ i ].palmPosition[ 1 ], json["hands"][ i ].palmPosition[ 2 ] );
          hand.rotation = new Matrix( x: new Vector3( json["hands"][ i ].r[ 0 ][ 0 ], json["hands"][ i ].r[ 0 ][ 1 ], json["hands"][ i ].r[ 0 ][ 2 ] ), y: new Vector3( json["hands"][ i ].r[ 1 ][ 0 ], json["hands"][ i ].r[ 1 ][ 1 ], json["hands"][ i ].r[ 1 ][ 2 ] ), z: new Vector3( json["hands"][ i ].r[ 2 ][ 0 ], json["hands"][ i ].r[ 2 ][ 1 ], json["hands"][ i ].r[ 2 ][ 2 ] ) );
          hand.scaleFactorNumber = json["hands"][ i ].s;
          hand.sphereCenter = new Vector3( json["hands"][ i ].sphereCenter[ 0 ], json["hands"][ i ].sphereCenter[ 1 ], json["hands"][ i ].sphereCenter[ 2 ] );
          hand.sphereRadius = json["hands"][ i ].sphereRadius;
          hand.timeVisible = json["hands"][ i ].timeVisible;
          hand.translationVector = new Vector3( json["hands"][ i ].t[ 0 ], json["hands"][ i ].t[ 1 ], json["hands"][ i ].t[ 2 ] );
          currentFrame.hands.add( hand );
        }
      }

      currentFrame.id = json["id"];
      //currentFrame.currentFramesPerSecond = json.currentFrameRate;

      // InteractionBox
      if ( json["interactionBox"] != null )
      {
        currentFrame.interactionBox = new InteractionBox();
        currentFrame.interactionBox.center = new Vector3( json["interactionBox"].center[ 0 ], json["interactionBox"].center[ 1 ], json["interactionBox"].center[ 2 ] );
        currentFrame.interactionBox.width = json["interactionBox"].size[ 0 ];
        currentFrame.interactionBox.height = json["interactionBox"].size[ 1 ];
        currentFrame.interactionBox.depth = json["interactionBox"].size[ 2 ];
      }

      // Pointables
      if ( json["pointables"] != null )
      {
        i = 0;
        length = json["pointables"].length;
        for ( i = 0; i < length; i++ )
        {
          isTool = json["pointables"][ i ].tool;
          if ( isTool )
            pointable = new Tool();
          else
            pointable = new Finger();

          pointable.frame = currentFrame;
          pointable.id = json["pointables"][ i ].id;
          pointable.hand = Controller.getHandByID( currentFrame, json["pointables"][ i ].handId );
          pointable.length = json["pointables"][ i ].length;
          pointable.direction = new Vector3( json["pointables"][ i ].direction[ 0 ], json["pointables"][ i ].direction[ 1 ], json["pointables"][ i ].direction[ 2 ] );
          pointable.tipPosition = new Vector3( json["pointables"][ i ].tipPosition[ 0 ], json["pointables"][ i ].tipPosition[ 1 ], json["pointables"][ i ].tipPosition[ 2 ] );
          pointable.stabilizedTipPosition = new Vector3( json["pointables"][ i ].stabilizedTipPosition[ 0 ], json["pointables"][ i ].stabilizedTipPosition[ 1 ], json["pointables"][ i ].stabilizedTipPosition[ 2 ] );
          pointable.tipVelocity = new Vector3( json["pointables"][ i ].tipVelocity[ 0 ], json["pointables"][ i ].tipVelocity[ 1 ], json["pointables"][ i ].tipVelocity[ 2 ] );
          pointable.touchDistance = json["pointables"][ i ].touchDist;
          pointable.timeVisible = json["pointables"][ i ].timeVisible;
          currentFrame.pointables.add( pointable );

          switch( json["pointables"][ i ].touchZone )
          {
            case "hovering":
              pointable.touchZone = Pointable.ZONE_HOVERING;
              break;
            case "touching":
              pointable.touchZone = Pointable.ZONE_TOUCHING;
              break;
            default:
              pointable.touchZone = Pointable.ZONE_NONE;
              break;
          }

          if ( pointable.hand != null )
            pointable.hand.pointables.add( pointable );

          if ( isTool )
          {
            pointable.isTool = true;
            pointable.isFinger = false;
            pointable.width = json["pointables"][ i ].width;
            currentFrame.tools.add( pointable );
            if ( pointable.hand != null )
              pointable.hand.toolsVector.add( pointable );
          }
          else
          {
            pointable.isTool = false;
            pointable.isFinger = true;
            currentFrame.fingers.add( pointable );
            if ( pointable.hand != null )
              pointable.hand.fingersVector.add( pointable );
          }
        }
      }

      // Gestures
      if ( json["gestures"] != null )
      {
        i = 0;
        length = json["gestures"].length;
        for ( i = 0; i < length; i++ )
        {
          switch( json["gestures"][ i ].type )
          {
            case "circle":
              gesture = new CircleGesture();
              type = Gesture.TYPE_CIRCLE;
              CircleGesture circle = gesture;

              circle.center = new Vector3( json["gestures"][ i ].center[ 0 ], json["gestures"][ i ].center[ 1 ], json["gestures"][ i ].center[ 2 ] );
              circle.normal = new Vector3( json["gestures"][ i ].normal[ 0 ], json["gestures"][ i ].normal[ 1 ], json["gestures"][ i ].normal[ 2 ] );
              circle.progress = json["gestures"][ i ].progress;
              circle.radius = json["gestures"][ i ].radius;
              break;

            case "swipe":
              gesture = new SwipeGesture();
              type = Gesture.TYPE_SWIPE;

              SwipeGesture swipe = gesture;

              swipe.startPosition = new Vector3( json["gestures"][ i ].startPosition[ 0 ], json["gestures"][ i ].startPosition[ 1 ], json["gestures"][ i ].startPosition[ 2 ] );
              swipe.position = new Vector3( json["gestures"][ i ].position[ 0 ], json["gestures"][ i ].position[ 1 ], json["gestures"][ i ].position[ 2 ] );
              swipe.direction = new Vector3( json["gestures"][ i ].direction[ 0 ], json["gestures"][ i ].direction[ 1 ], json["gestures"][ i ].direction[ 2 ] );
              swipe.speed = json["gestures"][ i ].speed;
              break;

            case "screenTap":
              gesture = new ScreenTapGesture();
              type = Gesture.TYPE_SCREEN_TAP;

              ScreenTapGesture screenTap = gesture;
              screenTap.position = new Vector3( json["gestures"][ i ].position[ 0 ], json["gestures"][ i ].position[ 1 ], json["gestures"][ i ].position[ 2 ] );
              screenTap.direction = new Vector3( json["gestures"][ i ].direction[ 0 ], json["gestures"][ i ].direction[ 1 ], json["gestures"][ i ].direction[ 2 ] );
              screenTap.progress = json["gestures"][ i ].progress;
              break;

            case "keyTap":
              gesture = new KeyTapGesture();
              type = Gesture.TYPE_KEY_TAP;

              KeyTapGesture keyTap = gesture;
              keyTap.position = new Vector3( json["gestures"][ i ].position[ 0 ], json["gestures"][ i ].position[ 1 ], json["gestures"][ i ].position[ 2 ] );
              keyTap.direction = new Vector3( json["gestures"][ i ].direction[ 0 ], json["gestures"][ i ].direction[ 1 ], json["gestures"][ i ].direction[ 2 ] );
              keyTap.progress = json["gestures"][ i ].progress;
              break;

            default:
              throw( "unkown gesture type" );
          }

          int j = 0;
          int lengthInner = 0;

          if( json["gestures"][ i ].handIds != null )
          {
            j = 0;
            lengthInner = json["gestures"][ i ].handIds.length;
            for( j = 0; j < lengthInner; ++j )
            {
              Hand gestureHand = Controller.getHandByID( currentFrame, json["gestures"][ i ].handIds[ j ] );
              gesture.hands.add( gestureHand );
            }
          }

          if( json["gestures"][ i ].pointableIds != null )
          {
            j = 0;
            lengthInner = json["gestures"][ i ].pointableIds.length;
            for( j = 0; j < lengthInner; ++j )
            {
              Pointable gesturePointable = Controller.getPointableByID( currentFrame, json["gestures"][ i ].pointableIds[ j ] );
              if( gesturePointable != null )
              {
                gesture.pointables.add( gesturePointable );
              }
            }
            if( gesture is CircleGesture && gesture.pointables.length > 0 )
            {
              (gesture as CircleGesture).pointable = gesture.pointables[ 0 ];
            }
          }

          gesture.frame = currentFrame;
          gesture.id = json["gestures"][ i ].id;
          gesture.duration = json["gestures"][ i ].duration;
          gesture.durationSeconds = gesture.duration / 1000000;

          switch( json["gestures"][ i ].state )
          {
            case "start":
              gesture.state = Gesture.STATE_START;
              break;
            case "update":
              gesture.state = Gesture.STATE_UPDATE;
              break;
            case "stop":
              gesture.state = Gesture.STATE_STOP;
              break;
            default:
              gesture.state = Gesture.STATE_INVALID;
          }

          gesture.type = type;

          currentFrame.gesturesVector.add( gesture );
        }
      }

      // Rotation (since last frame), interpolate for smoother motion
      if ( json["r"] )
        currentFrame.rotation = new Matrix( x: new Vector3( json["r"][ 0 ][ 0 ], json["r"][ 0 ][ 1 ], json["r"][ 0 ][ 2 ] ), y: new Vector3( json["r"][ 1 ][ 0 ], json["r"][ 1 ][ 1 ], json["r"][ 1 ][ 2 ] ), z: new Vector3( json["r"][ 2 ][ 0 ], json["r"][ 2 ][ 1 ], json["r"][ 2 ][ 2 ] ) );

      // Scale factor (since last frame), interpolate for smoother motion
      currentFrame.scaleFactorNumber = json["s"];

      // Translation (since last frame), interpolate for smoother motion
      if ( json["t"] )
        currentFrame.translationVector = new Vector3( json["t"][ 0 ], json["t"][ 1 ], json["t"][ 2 ] );

      // Timestamp
      currentFrame.timestamp = json["timestamp"];

      // Add frame to history
      if ( frameHistory.length > 59 )
        frameHistory.removeRange( 59, 1 );

      frameHistory.insert( 0, _latestFrame );
      _latestFrame = currentFrame;
      _listener.onFrame( this, _latestFrame );
    });
  }

  /**
   * Finds a Hand object by ID.
  *
   * @param frame The Frame object in which the Hand contains
   * @param id The ID of the Hand object
   * @return The Hand object if found, otherwise null
  *
   */
  static Hand getHandByID( Frame frame, int id )
  {
    Hand returnValue;
    int i = 0;

    for( i = 0; i < frame.hands.length; i++ )
    {
      if ( (frame.hands[ i ]).id == id )
      {
        returnValue = (frame.hands[ i ]);
        break;
      }
    }
    return returnValue;
  }

  /**
   * Finds a Pointable object by ID.
   *
   * @param frame The Frame object in which the Pointable contains
   * @param id The ID of the Pointable object
   * @return The Pointable object if found, otherwise null
  *
   */
  static Pointable getPointableByID( Frame frame, int id )
  {
    Pointable returnValue;
    int i = 0;

    for( i = 0; i < frame.pointables.length; i++ )
    {
      if ( (frame.pointables[ i ]).id == id )
      {
        returnValue = (frame.pointables[ i ]);
        break;
      }
    }
    return returnValue;
  }
  
  /**
   * Returns a frame of tracking data from the Leap Motion.
   *
   * <p>Use the optional history parameter to specify which frame to retrieve.
   * Call <code>frame()</code> or <code>frame(0)</code> to access the most recent frame;
   * call <code>frame(1)</code> to access the previous frame, and so on. If you use a history value
   * greater than the number of stored frames, then the controller returns
   * an invalid frame.</p>
   *
   * @param history The age of the frame to return, counting backwards from
   * the most recent frame (0) into the past and up to the maximum age (59).
   *
   * @return The specified frame; or, if no history parameter is specified,
   * the newest frame. If a frame is not available at the specified
   * history position, an invalid Frame is returned.
   *
   */
  Frame frame( { int history: 0 } )
  {
    if( history >= frameHistory.length )
      return Frame.invalid();
    else
      return frameHistory[ history ];
  }

  /**
   * Enables or disables reporting of a specified gesture type.
   *
   * <p>By default, all gesture types are disabled. When disabled, gestures of
   * the disabled type are never reported and will not appear in the frame
   * gesture list.</p>
   *
   * <p>As a performance optimization, only enable recognition for the types
   * of movements that you use in your application.</p>
   *
   * @param type The type of gesture to enable or disable. Must be a member of the Gesture::Type enumeration.
   * @param enable True, to enable the specified gesture type; False, to disable.
   *
   */
  void enableGesture( { int type, bool enable: true } )
  {
    //connection.enableGesture( type, enable );
  }

  /**
   * Reports whether the specified gesture type is enabled.
   *
   * @param type The Gesture.TYPE parameter.
   * @return True, if the specified type is enabled; false, otherwise.
   *
   */
  bool isGestureEnabled( int type )
  {
    //return connection.isGestureEnabled( type );
  }

  /**
   * Gets the active policy settings.
   *
   * <p>Use this function to determine the current policy state.
   * Keep in mind that setting a policy flag is asynchronous, so changes are
   * not effective immediately after calling <code>setPolicyFlag()</code>. In addition, a
   * policy request can be declined by the user. You should always set the
   * policy flags required by your application at startup and check that the
   * policy change request was successful after an appropriate interval.</p>
   *
   * <p>If the controller object is not connected to the Leap, then the default
   * policy state is returned.</p>
   *
   * @returns The current policy flags.
   */
  int policyFlags()
  {
    //return connection.policyFlags();
  }

  /**
   * Requests a change in policy.
   *
   * <p>A request to change a policy is subject to user approval and a policy
   * can be changed by the user at any time (using the Leap Motion settings window).
   * The desired policy flags must be set every time an application runs.</p>
   *
   * <p>Policy changes are completed asynchronously and, because they are subject
   * to user approval, may not complete successfully. Call
   * <code>Controller.policyFlags()</code> after a suitable interval to test whether
   * the change was accepted.</p>
   *
   * <p>Currently, the background frames policy is the only policy supported.
   * The background frames policy determines whether an application
   * receives frames of tracking data while in the background. By
   * default, the Leap Motion only sends tracking data to the foreground application.
   * Only applications that need this ability should request the background
   * frames policy.</p>
   *
   * <p>At this time, you can use the Leap Motion applications Settings window to
   * globally enable or disable the background frames policy. However,
   * each application that needs tracking data while in the background
   * must also set the policy flag using this function.</p>
   *
   * <p>This function can be called before the Controller object is connected,
   * but the request will be sent to the Leap Motion after the Controller connects.</p>
   *
   * @param flags A PolicyFlag value indicating the policies to request.
   */
  void setPolicyFlags( int flags )
  {
    //connection.setPolicyFlags( flags );
  }

  /**
   * Reports whether this Controller is connected to the Leap Motion Controller.
   *
   * <p>When you first create a Controller object, <code>isConnected()</code> returns false.
   * After the controller finishes initializing and connects to
   * the Leap, <code>isConnected()</code> will return true.</p>
   *
   * <p>You can either handle the onConnect event using a event listener
   * or poll the <code>isConnected()</code> function if you need to wait for your
   * application to be connected to the Leap Motion before performing
   * some other operation.</p>
   *
   * @return True, if connected; false otherwise.
   *
   */
  bool isConnected()
  {
    //return connection.isConnected;
  }
}