# Style Reference — Extended Examples

## Doc Comment Templates

### Class
```csharp
/** <summary>
 * One-sentence summary of what this class does.
 *
 * <para>Optional expanded explanation. Use <see cref="RelatedClass"/> to cross-reference.</para>
 *
 * <remarks>
 * Important constraints or invariants that callers must know.
 * </remarks>
 * </summary>
 */
public class ExampleClass : MonoBehaviour
```

### Public method
```csharp
/** <summary>
 * Summary sentence.
 * </summary>
 * <param name="value">What this parameter represents.</param>
 * <returns>What this returns.</returns>
 */
public int ComputeScore(int value)
```

### Multi-step method
```csharp
/** <summary>
 * Begins an insertion session for <paramref name="value"/> into the BST.
 *
 * <list type="number">
 * <item>Validates value is in range.</item>
 * <item>Creates the carrier view.</item>
 * <item>Raises <see cref="OnNavigationBegan"/>.</item>
 * </list>
 * </summary>
 */
public async UniTask BeginInsertion(int value)
```

### Tooltip examples
```csharp
[Tooltip("Duration (seconds) for the carrier to slide between positions.")]
[SerializeField] private float carrierMoveDuration = 0.2f;

[Tooltip("SO providing values inserted silently before gameplay starts. Leave empty for a blank tree.")]
[SerializeField] private SampleTreeProviderBase sampleTreeProvider;
```

## Full Class Example

```csharp
/** <summary>
 * Top-level MonoBehaviour that wires subsystems and drives the insertion game loop.
 * </summary>
 */
public class TreeGameController : MonoBehaviour
{
    #region Inspector Fields

    [Header("Configuration")]
    [Tooltip("Centralised tuning parameters for the tree visualizer.")]
    [SerializeField] private TreeVisualizerConfig config;

    [Header("Generator")]
    [Tooltip("Creates and configures the value generator. Assign IntValueGeneratorConfig or SmartIntValueGeneratorConfig.")]
    [SerializeField] private IntGeneratorConfig generatorConfig;

    [Header("Scene References")]
    [Tooltip("Prefab instantiated for each new tree node.")]
    [SerializeField] private GameObject nodePrefab;

    #endregion

    #region Private Systems

    private TreeNavigator<int> _navigator;
    private IntValueGeneratorBase _generator;
    private TreeLayoutManager<int> _layout;

    #endregion

    #region Private Fields

    private TreeNodeView _carrierView;
    private int _currentInsertValue;

    #endregion

    #region Properties

    public int ErrorCount { get; private set; }

    #endregion

    #region MonoBehaviour Callbacks

    private void Awake()
    {
        _generator = generatorConfig != null
            ? generatorConfig.CreateGenerator()
            : new IntValueGenerator();
    }

    private void OnDestroy()
    {
        // cleanup
    }

    #endregion

    #region Public API

    /** <summary>Resets error count and begins a new game session.</summary> */
    public void RestartSession()
    {
        ErrorCount = 0;
        BeginNextInsertion();
    }

    #endregion

    #region Helpers

    private void BeginNextInsertion()
    {
        if (generatorConfig != null) generatorConfig.UpdateGenerator(_generator);
        _generator.SetTreeContext(_navigator.Root);
        _currentInsertValue = _generator.GenerateNext();
        _navigator.BeginInsertion(_currentInsertValue).Forget();
    }

    #endregion
}
```

## Common Mistakes

### Inline comment (wrong)
```csharp
// Apply heatmap immediately so the newly placed node gets its gradient color
_layout.UpdateHeatmapColors(_navigator.Root);
```
Extract into a named method instead:
```csharp
ApplyHeatmapBeforeAnimation();
```

### Backing field pattern (wrong)
```csharp
private bool _isActive;
public bool IsActive => _isActive;
```
Use auto-property:
```csharp
public bool IsActive { get; private set; }
```

### Extra alignment (wrong)
```csharp
private TreeNavigator<int>    _navigator;
private IntValueGeneratorBase _generator;
private TreeLayoutManager<int> _layout;
```
Standard indentation only:
```csharp
private TreeNavigator<int> _navigator;
private IntValueGeneratorBase _generator;
private TreeLayoutManager<int> _layout;
```

### Triple-slash doc (wrong)
```csharp
/// <summary>
/// Creates a generator.
/// </summary>
```
Use C-style block:
```csharp
/** <summary>Creates a generator.</summary> */
```
