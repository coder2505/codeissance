// ARActivity.kt - With instruction display
package com.example.codeissance_project

import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.node.ModelNode
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import kotlin.math.*

class ARActivity : AppCompatActivity() {

    private lateinit var sceneView: ARSceneView
    private lateinit var instructionCard: CardView
    private lateinit var instructionText: TextView
    private lateinit var distanceText: TextView

    private var arrowNode: ModelNode? = null
    private var isModelLoaded = false

    private var lastUpdateTime = 0L
    private val UPDATE_INTERVAL_MS = 100L

    companion object {
        var latestARData: Map<String, Any>? = null

        @JvmStatic
        fun updateARData(data: Map<String, Any>) {
            Log.i("AR_DATA_PIPE", "Received AR data: $data")
            latestARData = data
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ar)

        initializeViews()
        setupARScene()
        loadArrowModel()
    }

    private fun initializeViews() {
        sceneView = findViewById(R.id.sceneView)
        instructionCard = findViewById(R.id.instructionCard)
        instructionText = findViewById(R.id.instructionText)
        distanceText = findViewById(R.id.distanceText)

        // Initially hide the instruction card
        instructionCard.visibility = android.view.View.GONE
    }

    private fun setupARScene() {
        sceneView.sessionConfiguration = { session: Session, config: Config ->
            config.depthMode = when (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                true -> Config.DepthMode.AUTOMATIC
                else -> Config.DepthMode.DISABLED
            }
            config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
            config.lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
        }

        sceneView.onSessionCreated = { session: Session ->
            Log.i("ARActivity", "AR Session created successfully")
        }

        sceneView.onSessionFailed = { exception: Exception ->
            Log.e("ARActivity", "AR Session failed: ${exception.message}", exception)
        }

        sceneView.onSessionUpdated = { session: Session, frame: Frame ->
            val currentTime = System.currentTimeMillis()

            if (isModelLoaded &&
                frame.camera.trackingState == TrackingState.TRACKING &&
                currentTime - lastUpdateTime > UPDATE_INTERVAL_MS) {

                latestARData?.let { data ->
                    try {
                        val distance = (data["distance"] as? Number)?.toDouble() ?: 0.0
                        val bearing = (data["bearing"] as? Number)?.toDouble() ?: 0.0
                        val instruction = data["instruction"] as? String ?: ""
                        val isFinalStep = data["isFinalStep"] as? Boolean ?: false

                        Log.d("ARActivity", "Processing AR update - Distance: ${distance}m, Bearing: ${bearing}°")

                        updateArrowPose(distance.toFloat(), bearing.toFloat())
                        updateInstructionDisplay(instruction, distance, isFinalStep)
                        lastUpdateTime = currentTime

                    } catch (e: Exception) {
                        Log.e("ARActivity", "Error processing AR data: ${e.message}", e)
                    }
                }
            }
        }
    }

    private fun loadArrowModel() {
        Log.i("ARActivity", "Starting to load arrow model...")

        sceneView.modelLoader.loadModelInstanceAsync(
            fileLocation = "arrow.glb",
            onResult = { modelInstance ->
                if (modelInstance != null) {
                    arrowNode = ModelNode(
                        modelInstance = modelInstance,
                        scaleToUnits = 1.0f
                    ).apply {
                        isVisible = false
                        position = Position(0f, -0.5f, -2.0f)
                    }

                    sceneView.addChildNode(arrowNode!!)
                    isModelLoaded = true

                    Log.i("ARActivity", "Arrow model loaded and added to scene")
                } else {
                    Log.e("ARActivity", "Model loading failed: modelInstance is null")
                    // Show fallback text arrow if model fails
                    showFallbackArrow()
                }
            },
//            onError = { exception ->
//                Log.e("ARActivity", "Model loading error: ${exception.message}", exception)
//                showFallbackArrow()
//            }
        )
    }

    private fun showFallbackArrow() {
        // If 3D model fails, you could add a 2D arrow overlay
        Log.i("ARActivity", "Using fallback arrow display")
        isModelLoaded = true // Allow updates to continue
    }

    private fun updateArrowPose(distance: Float, bearing: Float) {
        arrowNode?.let { node ->
            try {
                val bearingRadians = Math.toRadians(bearing.toDouble())
                val fixedDistance = 2.0f

                val x = sin(bearingRadians).toFloat() * fixedDistance
                val z = -cos(bearingRadians).toFloat() * fixedDistance

                node.position = Position(x, -0.3f, z)

                val rotationY = (bearing + 180).toFloat()
                node.rotation = Rotation(0f, Math.toRadians(rotationY.toDouble()).toFloat(), 0f)

                val scale = when {
                    distance < 10f -> 0.5f
                    distance < 50f -> 0.5f
                    distance < 200f -> 0.5f
                    else -> 0.8f
                }
                node.scale = Position(scale, scale, scale)

                node.isVisible = true

                Log.d("ARActivity", "Arrow updated - Distance: ${distance}m, Bearing: $bearing°")

            } catch (e: Exception) {
                Log.e("ARActivity", "Error updating arrow pose: ${e.message}", e)
            }
        }
    }

    private fun updateInstructionDisplay(instruction: String, distance: Double, isFinalStep: Boolean) {
        runOnUiThread {
            try {
                // Update instruction text
                instructionText.text = instruction

                // Format distance display
                val distanceStr = when {
                    distance < 1000 -> "${distance.toInt()}m"
                    else -> "${(distance / 1000).toInt()}.${((distance % 1000) / 100).toInt()}km"
                }

                // Add direction indicator based on distance
                val directionText = when {
                    isFinalStep -> "🏁 Destination"
                    distance < 50 -> "🔄 Turn ahead in $distanceStr"
                    distance < 200 -> "⬆️ Continue for $distanceStr"
                    else -> "📍 $distanceStr away"
                }

                distanceText.text = directionText

                // Show the card
                instructionCard.visibility = android.view.View.VISIBLE

                // Color coding based on distance
                val cardBackground = when {
                    isFinalStep -> androidx.core.content.ContextCompat.getColor(this, android.R.color.holo_green_light)
                    distance < 50 -> androidx.core.content.ContextCompat.getColor(this, android.R.color.holo_orange_light)
                    else -> androidx.core.content.ContextCompat.getColor(this, android.R.color.white)
                }
                instructionCard.setCardBackgroundColor(cardBackground)

                Log.d("ARActivity", "Updated instruction display: $instruction, Distance: $distanceStr")

            } catch (e: Exception) {
                Log.e("ARActivity", "Error updating instruction display: ${e.message}", e)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d("ARActivity", "AR Activity resumed")
    }

    override fun onPause() {
        super.onPause()
        Log.d("ARActivity", "AR Activity paused")
    }

    override fun onDestroy() {
        super.onDestroy()
        sceneView.destroy()
        Log.d("ARActivity", "AR Activity destroyed")
    }
}