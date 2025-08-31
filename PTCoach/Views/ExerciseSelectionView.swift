import SwiftUI

struct ExerciseSelectionView: View {
    @Binding var selectedExercise: ExerciseInfo
    let onExerciseSelected: ((ExerciseInfo) -> Void)?
    @Environment(\.presentationMode) var presentationMode
    
    init(selectedExercise: Binding<ExerciseInfo>, onExerciseSelected: ((ExerciseInfo) -> Void)? = nil) {
        self._selectedExercise = selectedExercise
        self.onExerciseSelected = onExerciseSelected
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ExerciseLibrary.shared.availableExercises, id: \.id) { exercise in
                    Button(action: {
                        selectedExercise = exercise
                        onExerciseSelected?(exercise)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(exercise.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack {
                                    Text(exercise.category.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(4)
                                    
                                    Text(exercise.difficulty.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Spacer()
                            
                            if exercise.id == selectedExercise.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
