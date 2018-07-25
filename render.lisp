(in-package #:play-with-verts)

;;------------------------------------------------------------

(defstruct-g (plight :layout :std-140)
  (pos :vec3)
  (color :vec3)
  (strength :float))

(defstruct-g (light-set :layout :std-140)
  (plights (plight 30))
  (count :int))

(defvar *lights* nil)
(defvar *lights-arr* nil)

;;------------------------------------------------------------

;; We will use this function as our vertex shader
(defun-g some-vert-stage ((vert g-pnt)
                          &uniform
                          (model->world :mat4)
                          (world->view :mat4)
                          (view->clip :mat4))
  (let* ((pos (pos vert))
         (normal (norm vert))
         (uv (tex vert))
         (model-pos (v! pos 1))
         (world-pos (* model->world model-pos))
         (view-pos (* world->view world-pos))
         (world-norm (* (m4:to-mat3 model->world) normal))
         (clip-pos (* view->clip view-pos)))

    (values clip-pos
            world-norm
            (s~ world-pos :xyz)
            uv)))

(defun-g lin-attenuate ((dist :float))
  (/ 1f0 dist))

(defun-g attenuate ((dist :float))
  (/ 1f0 (* dist dist)))

(defun-g gamma-correct ((color :vec3))
  (expt color (vec3 2.2)))

(defun-g gamma-encode ((color :vec3))
  (expt color (vec3 (/ 1.0 2.2))))

(defun-g calc-light ((frag-pos :vec3)
                     (frag-normal :vec3)
                     (light plight))
  (let* ((vec-to-light (- (plight-pos light) frag-pos))
         (dir-to-light (normalize vec-to-light))
         (point-light-strength
          (* (saturate (dot dir-to-light frag-normal))
             (plight-strength light))))
    (* point-light-strength
       (attenuate (length vec-to-light))
       (plight-color light))))

(defun-g some-frag-stage ((frag-normal :vec3)
                          (pos :vec3)
                          (uv :vec2)
                          &uniform
                          (albedo :sampler-2d)
                          (now :float)
                          (lights light-set :ubo))

  (let* (;; process inputs
         (normal (normalize frag-normal))
         ;;
         (albedo (gamma-correct (s~ (texture albedo uv) :xyz)))
         ;;
         (ambient (vec3 0.235))
         (diffuse-power (vec3 0.0)))
    ;;
    (with-slots (plights count) lights
      (dotimes (i count)
        (incf diffuse-power
              (calc-light pos normal (aref plights i)))))
    ;;
    (let* ((light-amount (+ ambient diffuse-power))
           (color (* albedo light-amount) 0)
           (final-color (tone-map-uncharted2 color 1.0 2f0))
           (luma (rgb->luma-bt601 final-color)))
      (v! final-color luma))))

(defpipeline-g some-pipeline ()
  (some-vert-stage g-pnt)
  (some-frag-stage :vec3 :vec3 :vec2))

;;------------------------------------------------------------

(defun-g vert-stage-with-norms ((vert g-pnt)
                          &uniform
                          (model->world :mat4)
                          (world->view :mat4)
                          (view->clip :mat4))
  (let* ((pos (pos vert))
         (normal (norm vert))
         (uv (tex vert))
         (model-pos (v! pos 1))
         (world-pos (* model->world model-pos))
         (view-pos (* world->view world-pos))
         (world-norm (* (m4:to-mat3 model->world) normal))
         (clip-pos (* view->clip view-pos)))

    (values clip-pos
            world-norm
            (s~ world-pos :xyz)
            uv)))

(defun-g frag-stage-with-norms ((frag-normal :vec3)
                          (pos :vec3)
                          (uv :vec2)
                          &uniform
                          (albedo :sampler-2d)
                          (now :float)
                          (lights light-set :ubo))

  (let* (;; process inputs
         (normal (normalize frag-normal))
         ;;
         (albedo (gamma-correct (s~ (texture albedo uv) :xyz)))
         ;;
         (ambient (vec3 0.235))
         (diffuse-power (vec3 0.0)))
    ;;
    (with-slots (plights count) lights
      (dotimes (i count)
        (incf diffuse-power
              (calc-light pos normal (aref plights i)))))
    ;;
    (let* ((light-amount (+ ambient diffuse-power))
           (color (* albedo light-amount) 0)
           (final-color (tone-map-uncharted2 color 1.0 2f0))
           (luma (rgb->luma-bt601 final-color)))
      (v! final-color luma))))

(defpipeline-g some-pipeline-with-norms ()
  (vert-stage-with-norms g-pnt)
  (frag-stage-with-norms :vec3 :vec3 :vec2))
