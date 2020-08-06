;; -*- mode: lisp;-*-
(load "package://pr2eus/pr2-interface.l")
(require :robot-oculus-interface "package://eus_vive/euslisp/lib/robot-oculus-interface.l")


(defclass pr2-oculus-interface
  :super robot-oculus-interface
  :slots ())


(defmethod pr2-oculus-interface
  (:init (&rest args)
    (send self :set-val 'robot *pr2*)
    (send self :set-val 'robot-interface *ri*)
    (send self :set-val 'camera-model *camera-model*)
    (send self :set-val 'rate 10)
    (send self :set-val 'end-coords-pos-diff-thresh 400)
    (send self :set-val 'draw-object-list (list *pr2*))
    ;; for oculus
    (send self :set-val 'hmd-pose-topic-name "/oculus/hmd/pose_stamped")
    (send self :set-val 'left-controller-pose-topic-name "/oculus/left_controller/pose_stamped")
    (send self :set-val 'right-controller-pose-topic-name "/oculus/right_controller/pose_stamped")
    ;; for pr2
    (send self :set-val 'base-frame-id "base_footprint")
    (send self :set-val 'head-frame-id "head_tilt_link")
    (send self :set-val 'ik-stop-step 10)
    (send self :set-val 'scale 1.5)
    (send self :set-val 'av-tm 300)
    (send self :set-val 'av-scale 5.0)
    (send self :set-val 'min-time 0.3)
    (send self :set-val 'torso-av-tm 500)
    (send self :set-val 'torso-av-scale 1.5)
    (send self :set-val 'torso-min-time 0.5)
    (send self :set-val 'torso-z-thresh 100)
    (send self :set-val 'torso-ik-weight 0.0001)
    (send self :set-val 'grasp-timeout-time nil)
    (send self :set-val 'arm-length 600)
    (send self :set-val 'head->shoulder-x-distance 100)
    (send self :set-val 'head->shoulder-z-distance 50)
    (send self :set-val 'gripper-status-topic-name
          '(format nil "/~A_gripper_controller/gripper_action/status" (if (eq arm :larm) "l" "r")))
    (send-super* :init args))
  (:reset-service (req)
    (let ((res (instance std_srvs::EmptyResponse :init)))
      (send self :reset :loop-enable nil)
      (send self :stop-grasp :arms :wait nil)
      (send self :angle-vector (send robot :reset-pose) 5000)
      (send robot-interface :wait-interpolation)
      res))
  (:angle-vector (&rest args)
    (send* robot-interface :angle-vector args))
  (:inverse-kinematics (arm target-coords &rest args)
    (if (eq arm :arms)
      (send* robot :inverse-kinematics target-coords :rotation-axis (list t t)
             :move-target (list (send robot :larm :end-coords) (send robot :rarm :end-coords))
             :avoid-collision-distance 5 :revert-if-fail nil :stop ik-stop-step
             :debug-view nil args)
      (send* robot :inverse-kinematics target-coords
             :rotation-axis t :move-target (send robot arm :end-coords)
             :avoid-collision-distance 5 :revert-if-fail nil :stop ik-stop-step
             :debug-view nil args)))
  (:start-grasp (arm &key (wait t))
    (send robot-interface :start-grasp arm :wait wait :gain (/ 50.0 2000))))


(defun pr2-oculus-init (&key (loop-enable t))
  (pr2-init)
  (objects (list *pr2*))
  (setq *camera-model*
        (make-camera-from-param :pwidth 640 :pheight 640 :fx 400 :fy 400 :cx 319.5 :cy 319.5))
  (send *camera-model* :translate #f(1500 0 800))
  (send *camera-model* :rotate -1.57 :y :world)
  (send *camera-model* :rotate -1.57 :x :world)
  (setq *ti* (instance pr2-oculus-interface :init :loop-enable loop-enable)))


(defun signal-hook (sig code)
  (when (boundp '*ri*)
    (send *ri* :cancel-angle-vector :controller-type :larm-controller)
    (send *ri* :cancel-angle-vector :controller-type :rarm-controller)
    (send *ri* :cancel-angle-vector :controller-type :torso-controller))
  (reset))

(unix:signal 2 'signal-hook)
(unix:signal 15 'signal-hook)